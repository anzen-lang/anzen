import AST
import Utils

// let SOLVER_TIMEOUT: Stopwatch.TimeInterval? = Stopwatch.TimeInterval(s: 10)
let SOLVER_TIMEOUT: Stopwatch.TimeInterval? = nil

public struct ConstraintSolver {

  public init<S>(constraints: S, in context: ASTContext, assumptions: SubstitutionTable = [:])
    where S: Sequence, S.Element == Constraint
  {
    self.context = context
    self.constraints = constraints.sorted(by: <)
    self.assumptions = assumptions
  }

  /// The AST context.
  public let context: ASTContext
  // The constraints that are yet to be solved.
  private var constraints: [Constraint]
  // The assumptions made so far on the free types of the AST.
  private var assumptions: SubstitutionTable

  private typealias Success = SubstitutionTable
  private typealias Failure = (constraint: Constraint, cause: SolverResult.FailureKind)

  /// Attempts to solve a set of typing constraints, returning either a solution or the constraints
  /// that couldn't be satisfied.
  public mutating func solve() -> SolverResult {
    let stopwatch = Stopwatch()

    while let constraint = constraints.popLast() {
      guard (SOLVER_TIMEOUT == nil) || (stopwatch.elapsed < SOLVER_TIMEOUT!)
        else { return .failure([(reify(constraint: constraint), .timeout)]) }

      switch constraint.kind {
      case .equality, .conformance:
        guard solve(match: constraint) == .success else {
          return .failure([(reify(constraint: constraint), .typeMismatch)])
        }

        // FIXME: Instead of returning upon failure, we should bind variables to `<type error>` and
        // try to solve the remainder of the constraints. This would make for more comprehensive
        // diagnostics as it would let us detect additional errors as well.

      case .member:
        guard solve(member: constraint) == .success else {
          return .failure([(reify(constraint: constraint), .typeMismatch)])
        }

      case .construction:
        guard solve(construction: constraint) == .success else {
          return .failure([(reify(constraint: constraint), .typeMismatch)])
        }

      case .disjunction:
        // Solve each branch with a sub-solver.
        var results: [SolverResult] = []
        for choice in constraint.choices {
          var subsolver = ConstraintSolver(
            constraints: constraints + [choice],
            in: context,
            assumptions: assumptions)
          results.append(subsolver.solve())
        }

        // Collect all valid solutions.
        var valid = results.compactMap { result -> Success? in
           guard case .success(let solution) = result else { return nil }
           return solution
        }

        switch valid.count {
        case 0:
          let unsolvable = results.compactMap { result -> [Failure]? in
            guard case .failure(let cause) = result else { return nil }
            return cause
          }
          return .failure(Array(unsolvable.joined()))

        case 1:
          return .success(solution: valid[0])

        default:
          // If there are several solutions, we have to try selecting the most specific one. Note
          // that it is possible for two solvers to find the same solution, as one may have received
          // a constraint that didn't add any information to the assumptions. Hence the first step
          // is to identify duplicates.
          var candidates: [Success] = []
          for solution in valid {
            let candidate = solution.reified(in: context)
            // Yep, this is a an ugly linear search! But We work on the assumption that the size of
            // the list of solutions doesn't justify the use of a more sophisticated technique.
            if !candidates.contains(where: { $0.isEquivalent(to: candidate) }) {
              candidates.append(candidate)
            }
          }

          assert(candidates.count > 0)
          if candidates.count == 1 {
            return .success(solution: candidates[0])
          }

          // If they are several *different* solutions, we attempt to find the most specific one.
          // Note that there isn't a total order on "being more specific than".
          outer:for i in 0 ..< candidates.count {
            inner:for j in 0 ..< candidates.count {
              guard j != i else { continue inner }
              guard candidates[i].isMoreSpecific(than: candidates[j]) else { continue outer }
            }
            return .success(solution: candidates[i])
          }

          // There's still equivalent solutions; the constraint system is ambiguous.
          return .failure([(reify(constraint: constraint), .ambiguousExpression)])
        }
      }
    }

    return .success(solution: assumptions)
  }

  /// Attempts to match `T` and `U`, effectively solving a given constraint between those types.
  private mutating func solve(match constraint: Constraint) -> TypeMatchResult {
    // Get the substitutions we already inferred for `T` and `U` if they are type variables.
    var a = assumptions.substitution(for: constraint.types!.t)
    var b = assumptions.substitution(for: constraint.types!.u)

    // If the types are obviously equivalent, we're done.
    guard a != b else { return .success }

    // Open unbound generic types.
    if let generic = a as? GenericType, !generic.placeholders.isEmpty {
      a = assumptions.reify(type: a, in: context).open(in: context)
    }
    if let generic = b as? GenericType, !generic.placeholders.isEmpty {
      b = assumptions.reify(type: b, in: context).open(in: context)
    }

    // Close bound generic types, if the unbound type has already been infered. If that's not the
    // case, the constraint has to be postponed, as we have no way to determine the final closing
    // of the bound generic represents.
    if let bound = a as? BoundGenericType {
      let unbound = assumptions.reify(type: bound.unboundType, in: context)
      if unbound is TypeVariable {
        constraints.insert(constraint, at: 0)
        return .success
      }
      a = unbound.close(using: bound.bindings, in: context)
    }
    if let bound = b as? BoundGenericType {
      let unbound = assumptions.reify(type: bound.unboundType, in: context)
      if unbound is TypeVariable {
        constraints.insert(constraint, at: 0)
        return .success
      }
      b = unbound.close(using: bound.bindings, in: context)
    }

    switch (a, b) {
    case (let var_ as TypeVariable, _):
      if constraint.kind == .conformance {
        if b is TypeVariable {
          // If both `T` and `U` are unknown, we can't solve the conformance constraint yet.
          constraints.insert(constraint, at: 0)
          return .success
        }

        // If only `T` is unknown, trying to unify it with `U` might be too broad. Instead, we
        // should compute the "join" of both types. We do that by creating a dusjunction that either
        // unifies `T` with `U`, or postpones the conformance constraint until we can infer `T`.
        let choices: [Constraint] = [
          .equality(t: a, u: b, at: constraint.location),
          constraint,
        ]
        constraints.insert(.disjunction(choices, at: constraint.location), at: 0)
        return .success
      }

      assumptions.set(substitution: b, for: var_)
      return .success

    case (_, let var_ as TypeVariable):
      if constraint.kind == .conformance {
        // If only `U` is unknown, trying to unify it with `T` might be too specific. Instead, we
        // should compute the "meet" of both types. We do that by creating a set of assumptions that
        // each try to constraint `U` with a compatible type, starting from `T` and falling back to
        // a "super" type until we reach `Anything`.
        if a == AnythingType.get {
          // Since Anything is the top of the lattice, we don't need to find "super" type.
          assumptions.set(substitution: a, for: var_)
          return .success
        }

        // FIXME: Until we implement interface conformance, the set of "super" types of a type can
        // only be composed of the type itself together with `Anything`.
        let choices: [Constraint] = [
          .equality(t: b, u: a, at: constraint.location),
          .equality(t: b, u: AnythingType.get, at: constraint.location),
        ]
        constraints.insert(.disjunction(choices, at: constraint.location), at: 0)
        return .success
      }

      assumptions.set(substitution: a, for: var_)
      return .success

    case (_, AnythingType.get) where constraint.kind == .conformance:
      // All types trivially conform to `Anything`.
      return .success

    case (let fnl as FunctionType, let fnr as FunctionType):
      // Function types never match if their domains have different lenghts or labels
      guard
        fnl.domain.count == fnr.domain.count,
        zip(fnl.domain, fnr.domain).all(satisfy: { $0.0.label == $0.1.label }) else
      { return .failure }

      // Simplify the constraint.
      for (i, parameters) in zip(fnl.domain, fnr.domain).enumerated() {
        constraints.append(Constraint(
          kind: constraint.kind,
          types: (parameters.0.type, parameters.1.type),
          location: constraint.location + ConstraintPath.parameter(i)))
      }
      constraints.append(Constraint(
        kind: constraint.kind,
        types: (fnl.codomain, fnr.codomain),
        location: constraint.location + ConstraintPath.codomain))
      return .success

    case (_ as StructType, _ as StructType):
      // Since nominal types are unique, equality between `T` and `U` should have been trivially
      // solved when we checked whether or not `T` is `U`.
      guard constraint.kind == .conformance else { return .failure }

      // FIXME: Unlike an equality constraint, a conformance constraint shall be satisfied if `U`
      // is an interface that `T` implements.
      return .failure

    case (let bl as BoundGenericType, let br as BoundGenericType):
      // Bound generic types won't match if they don't have the same bindings.
      guard Set(bl.bindings.keys) == Set(br.bindings.keys)
        else { return .failure }

      // Simplify the constraint.
      for (key, type) in bl.bindings {
        constraints.append(Constraint(
          kind: constraint.kind,
          types: (type, br.bindings[key]!),
          location: constraint.location + ConstraintPath.binding(key)))
      }
      constraints.append(Constraint(
        kind: constraint.kind,
        types: (bl.unboundType, br.unboundType),
        location: constraint.location))
      return .success

    default:
      return .failure
    }
  }

  /// Attempts to solve `T[.name] ~= U`.
  private mutating func solve(member constraint: Constraint) -> TypeMatchResult {
    var owner = assumptions.substitution(for: constraint.types!.t)
    var bindings: [PlaceholderType: TypeBase]? = nil
    if let bound = owner as? BoundGenericType {
      owner = assumptions.substitution(for: bound.unboundType)
      bindings = bound.bindings
    }

    // Search a member (property or method) named `member` in the owner's type.
    switch owner {
    case is TypeVariable:
      // If the owner's type is unknown, we can't solve the constraint yet.
      constraints.insert(constraint, at: 0)
      return .success

    case let nominalType as NominalType:
      let members = nominalType.members.filter { $0.name == constraint.member! }
      guard !members.isEmpty
        else { return .failure }

      // Create a disjunction of membership constraints for each overloaded member.
      let choices = members.map { (member) -> Constraint in
        // If the owner is a bound generic type, close the found member with the same bindings.
        var u = bindings != nil
          ? assumptions.reify(type: member.type!, in: context).close(using: bindings!, in: context)
          : member.type!
        if member.isMethod {
          u = (u as! FunctionType).codomain
        }

        return Constraint.equality(t: constraint.types!.u, u: u, at: constraint.location)
      }

      if choices.count == 1 {
        constraints.append(choices[0])
      } else {
        constraints.insert(.disjunction(choices, at: constraint.location), at: 0)
      }
      return .success

    case is Metatype:
      // Such situation may happen if we have for instance `let add = Int.+`.
      fatalError("TODO")

    default:
      return .failure
    }
  }

  /// Attempts to solve `T <+ U`.
  private mutating func solve(construction constraint: Constraint) -> TypeMatchResult {
    let owner = self.assumptions.substitution(for: constraint.types!.t)

    // Search a member (property or method) named `member` in the owner's type.
    switch owner {
    case is TypeVariable:
      // If the owner's type is unknown, we can't solve the constraint yet.
      constraints.insert(constraint, at: 0)
      return .success

    case let metaType as Metatype:
      // A construction constraint can be transformed into a membership constraint with `T.type` as
      // the owner and `new` as the member.
      constraints.append(
        .member(t: metaType.type, member: "new", u: constraint.types!.u, at: constraint.location))
      return .success

    default:
      // If the owner isn't a metatype, the constraint can't be solved.
      return .failure
    }

    // FIXME: Handle opened and closed generics.
  }

  /// Reify the types of a constraint.
  private func reify(constraint: Constraint) -> Constraint {
    return Constraint(
      kind: constraint.kind,
      types: constraint.types.map({ (t, u) -> (TypeBase, TypeBase) in
        let a = assumptions.reify(type: t, in: context)
        let b = assumptions.reify(type: u, in: context)
        return (a, b)
      }),
      member: constraint.member,
      choices: constraint.choices.map(reify),
      location: constraint.location)
  }

}

private enum TypeMatchResult {

  case success
  case failure

}

public enum SolverResult {

  public enum FailureKind {
    case ambiguousExpression
    case timeout
    case typeMismatch
  }

  case success(solution: SubstitutionTable)
  case failure([(constraint: Constraint, cause: FailureKind)])

  public var isSuccess: Bool {
    if case .success = self {
      return true
    }
    return false
  }

}
