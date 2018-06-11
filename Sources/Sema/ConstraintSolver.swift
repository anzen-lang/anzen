import AST
import Utils

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
  // The penalties on the solution.
  private var penalties: Int = 0

  private typealias Success = (solution: SubstitutionTable, penalties: Int)
  private typealias Failure = (constraint: Constraint, cause: SolverResult.FailureKind)

  /// Attempts to solve a set of typing constraints, returning either a solution or the constraints
  /// that couldn't be satisfied.
  public mutating func solve() -> SolverResult {
    while let constraint = constraints.popLast() {
      switch constraint.kind {
      case .equality, .conformance:
        // Attempt to solve the match-relation constraint.
        guard solve(match: constraint) == .success else {
          return .failure([(reify(constraint: constraint), .typeMismatch)])
        }

        // FIXME: Instead of returning upon failure, we should bind variables to `<type error>` and
        // try to solve the remainder of the constraints. This would make for more comprehensive
        // diagnostics as it would let us detect additional errors as well.

      case .member:
        // Attempt to solve the membership constraint.
        guard solve(member: constraint) == .success else {
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
           guard case .success(let solution, let penalties) = result else { return nil }
           return (solution, penalties)
        }

        switch valid.count {
        case 0:
          let unsolvable = results.compactMap { result -> [Failure]? in
            guard case .failure(let cause) = result else { return nil }
            return cause
          }
          return .failure(Array(unsolvable.joined()))

        case 1:
          return .success(solution: valid[0].solution, penalties: valid[0].penalties)

        default:
          // If there are several solutions, we have to try selecting the most specific one.
          var best: [SubstitutionTable] = []
          var lowestPenalties = Int.max
          for candidate in valid {
            if candidate.penalties < lowestPenalties {
              best = [candidate.solution]
              lowestPenalties = candidate.penalties
            } else if candidate.penalties == lowestPenalties {
              best.append(candidate.solution)
            }
          }

          // Note that it is possible for two solvers to find the same solution, as one may have
          // received a constraint that didn't add any information to the assumptions, hence the
          // use of a set to eliminate duplicates.
          let candidates = Set(best.map({ $0.reified(in: context) }))
          if candidates.count == 1 {
            // We were able to identify a single unique solution after checking their penalties.
            return .success(solution: best.first!, penalties: lowestPenalties + penalties)
          }

          // If there are several solutions with the same number of penalties, we compare them to
          // find the most specific one.
          outer:for i in candidates.indices {
            inner:for j in candidates.indices {
              guard j != i else { continue inner }
              guard candidates[i].isMoreSpecific(than: candidates[j]) else { continue outer }
            }
            return .success(solution: candidates[i], penalties: lowestPenalties + penalties)
          }

          // There's still equivalent solutions; the constraint system is ambiguous.
          return .failure([(reify(constraint: constraint), .ambiguousExpression)])
        }
      }
    }

    return .success(solution: assumptions, penalties: penalties)
  }

  /// Attempts to match `T` and `U`, effectively solving a given constraint between those types.
  private mutating func solve(match constraint: Constraint) -> TypeMatchResult {
    // Get the substitutions we already inferred for `T` and `U` if they are type variables.
    var a = assumptions.substitution(for: constraint.types!.t)
    var b = assumptions.substitution(for: constraint.types!.u)

    // If the types are obviously equivalent, we're done.
    guard a != b else { return .success }

    // If either `T` or `U` is an unbound generic type, we "open" it. We also penalize the current
    // solution, so as to favor the selection of monomorphic types.
    if let generic = a as? GenericType, !generic.placeholders.isEmpty {
      a = open(type: a)
      penalties += 1
    }
    if let generic = b as? GenericType, !generic.placeholders.isEmpty {
      b = open(type: b)
      penalties += 1
    }

    // If either `T` or `U` is closed but couldn't be reified, we have to postpone the constraint.
    if a is ClosedGenericType || b is ClosedGenericType {
      constraints.insert(constraint, at: 0)
      return .success
    }

    switch (a, b) {
    case (let var_ as TypeVariable, _):
      if constraint.kind == .conformance && b is TypeVariable {
        // If both `T` and `U` are unknown, we can't solve the conformance constraint yet.
        constraints.insert(constraint, at: 0)
        return .success
      }

      // ASSUMPTION: Even in the case of a conformance match, we can unify `T` with `U` if the
      // former's unknown, as any constraint that would require `t > u` would leave to an invalid
      // program. In other words, we assume `T = join(T, U)` if `T` is a type variable.
      //
      // If this assumption is proved wrong, we'll have to actually compute the "join" of `T` and
      // `U`, using `U` as the upper bound.
      assumptions.set(substitution: b, for: var_)
      return .success

    case (_, let var_ as TypeVariable):
      if constraint.kind == .conformance {
        // If only the right type of a conformance match is unknown, trying to unify it with the
        // left side might be too specific. To tackle this problem, we should create a set of
        // assumptions that each will try to constraint the unknown type to a type compatible with
        // the left one, starting from the most specific one, and ending at `Anything`.
        //
        // FIXME: Until we implement interface conformance, the set of "super-types" of a type can
        // only be composed of the type itself together with `Anything`.
        let choices: [Constraint] = [
          .equality(t: b, u: a, at: constraint.location),
          .equality(t: b, u: TypeBase.anything, at: constraint.location),

        ]
        constraints.insert(.disjunction(choices, at: constraint.location), at: 0)
        return .success
      }

      assumptions.set(substitution: a, for: var_)
      return .success

    case (_, TypeBase.anything) where constraint.kind == .conformance:
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

    default:
      return .failure
    }
  }

  /// Attempts to solve `T[.name] ~= U`.
  private mutating func solve(member constraint: Constraint) -> TypeMatchResult {
    let owner = self.assumptions.substitution(for: constraint.types!.t)

    // Search a member (property or method) named `member` in the owner's type.
    switch owner {
    case is TypeVariable:
      // If the owner's type is unknown, we can't solve the constraint yet.
      constraints.insert(constraint, at: 0)
      return .success

    case let structType as StructType:
      guard let members = structType.members[constraint.member!]
        else { return .failure }

      // Create a disjunction of membership constraints for each overloaded member.
      let choices = members.map {
        Constraint.equality(t: constraint.types!.u, u: $0, at: constraint.location)
      }
      if choices.count == 1 {
        constraints.append(choices[0])
      } else {
        constraints.insert(.disjunction(choices, at: constraint.location), at: 0)
      }
      return .success

    default:
      return .failure
    }
  }

  /// Opens a type, effectively replacing its placeholders with fresh variables.
  private func open(
    type: TypeBase, with bindings: [PlaceholderType: TypeVariable] = [:]) -> TypeBase
  {
    // Reify variables, in case they were already bound to a type that needs to be opened.
    switch type {
    case let metatype as Metatype:
      return open(type: metatype.type, with: bindings).metatype

    case let placeholder as PlaceholderType:
      return bindings[placeholder] ?? placeholder

    case let nominalType as NominalType:
      // Make sure the type needs to be open.
      guard !nominalType.placeholders.isEmpty else { return nominalType }

      // Notice that nominal types aren't opened recursively. Instead, we simply store what fresh
      // variables placeholders should be bound to. Those will be used to close the in subsequent
      // type matches.
      let updatedBindings = bindings.merging(
        nominalType.placeholders.map { (key: $0, value: TypeVariable()) },
        uniquingKeysWith: { lhs, _ in lhs })
      return OpenedNominalType(unboundType: nominalType, bindings: updatedBindings)

    case let functionType as FunctionType:
      // Make sure the type needs to be open.
      guard !functionType.placeholders.isEmpty else { return functionType }

      // As functions do not need to retain which types their placeholders were bound to, opening
      // one amounts to create a new monomorphic version where placeholder are substituted with
      // fresh variables.
      let updatedBindings = bindings.merging(
        functionType.placeholders.map { (key: $0, value: TypeVariable()) },
        uniquingKeysWith: { lhs, _ in lhs })
      return context.getFunctionType(
        from: functionType.domain.map({
          Parameter(label: $0.label, type: open(type: $0.type, with: updatedBindings))
        }),
        to: open(type: functionType.codomain, with: updatedBindings))

    case let var_ as TypeVariable:
      let reified = assumptions.substitution(for: type)
      if reified is TypeVariable {
        // If the type is unknown at this point, wrap it inside a `ClosedGenericType` so that it
        // can be reified later.
        return ClosedGenericType(unboundType: var_, bindings: bindings)
      } else {
        return open(type: reified, with: bindings)
      }

    case let abstract:
      fatalError("can't open abstract type \(Swift.type(of: abstract))")
    }
  }

  /// Closes a type, effectively replacing its placeholders with their given substitution.
  private func close(type: TypeBase, with bindings: [PlaceholderType: TypeBase]) -> TypeBase {
    switch type {
    case let metatype as Metatype:
      return close(type: metatype.type, with: bindings).metatype

    case let placeholder as PlaceholderType:
      return bindings[placeholder].map {
        assumptions.substitution(for: $0)
      } ?? placeholder

    case is NominalType, is FunctionType:
      fatalError("todo")

    case let closedGeneric as ClosedGenericType:
      let reified = assumptions.substitution(for: closedGeneric.unboundType)
      if reified is TypeVariable {
        // We can't close the type if it's still unknown.
        return closedGeneric
      } else {
        return close(type: reified, with: bindings)
      }

    case is TypeVariable:
      unreachable()

    case let abstract:
      fatalError("can't close abstract type \(Swift.type(of: abstract))")
    }
  }

  /// Reify the types of a constraint.
  private func reify(constraint: Constraint) -> Constraint {
    switch constraint.kind {
    case .equality, .conformance, .member:
      let t = assumptions.reify(type: constraint.types!.t, in: context)
      let u = assumptions.reify(type: constraint.types!.u, in: context)
      return Constraint(kind: constraint.kind, types: (t, u), location: constraint.location)

    case .disjunction:
      return .disjunction(constraint.choices.map(reify), at: constraint.location)
    }
  }

}

private enum TypeMatchResult {

  case success
  case failure

}

public enum SolverResult {

  public enum FailureKind {
    case typeMismatch
    case ambiguousExpression
  }

  case success(solution: SubstitutionTable, penalties: Int)
  case failure([(constraint: Constraint, cause: FailureKind)])

  public var isSuccess: Bool {
    if case .success = self {
      return true
    }
    return false
  }

}
