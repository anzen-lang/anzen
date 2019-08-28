import AST

private let ERROR_WEIGHT = 1000000

/// A type constraint solver.
struct TypeConstraintSolver {

  /// The result of a solver.
  struct SolverResult {

    let substitutions: SubstitutionTable
    let weight: Int
    let errors: [TypeError]

  }

  /// The compiler context.
  private var context: CompilerContext

  /// The constraints that are yet to be solved.
  private var constraints: [TypeConstraint]

  /// The assumptions on the substitutions for type variables.
  private var assumptions: SubstitutionTable

  /// The type errors detected during constraint solving.
  private var errors: [TypeError] = []

  /// The current solution's weight.
  private var weight: Int

  /// The weight of the best solution so far.
  private var bestWeight: Int

  init<S>(
    constraints: S,
    context: CompilerContext,
    assumptions: SubstitutionTable,
    weight: Int = 0,
    bestWeight: Int = Int.max)
    where S: Sequence, S.Element == TypeConstraint
  {
    self.context = context
    self.constraints = constraints.sorted(by: { type(of: $0).priority < type(of: $1).priority })
    self.assumptions = assumptions
    self.weight = weight
    self.bestWeight = bestWeight
  }

  mutating func solve() -> SolverResult {
    while let constraint = constraints.popLast() {
      // Make sure the current solution is still worth exploring.
      guard weight <= bestWeight
        else { break }

      switch constraint {
      case let equality as TypeEqualityConstraint:
        solve(equality)

      case let conformance as TypeConformanceConstraint:
        solve(conformance)

//      case let construction as TypeConstructionConstraint:
//        solve(construction)

      case let specialization as TypeSpecializationConstraint:
        solve(specialization)

      case let valueMembership as TypeValueMemberConstraint:
        solve(valueMembership)

      case let disjunction as TypeConstraintDisjunction:
        var solutions: [SolverResult] = []
        for choice in disjunction.choices {
          // Create a sub-solver for each given choice and use it to compute a solution.
          var subsolver = TypeConstraintSolver(
            constraints: constraints + [choice.constraint],
            context: context,
            assumptions: assumptions,
            weight: weight + choice.weight,
            bestWeight: bestWeight)
          let newSolution = subsolver.solve()

          // Keep the cheapest solution(s).
          if solutions.isEmpty {
            bestWeight = newSolution.weight
            solutions.append(newSolution)
          } else if newSolution.weight < solutions[0].weight {
            bestWeight = newSolution.weight
            solutions = [newSolution]
          } else if newSolution.weight == solutions[0].weight {
            solutions.append(newSolution)
          }
        }

        if solutions.count == 1 {
          // There is only one solution, so we simply return in.
          return solutions[0]
        } else {
          // There are multiple equivalent solutions.
          fatalError("TODO: ambiguous constraint")
        }

      default:
        assertionFailure("bad type constraint '\(type(of: constraint))'")
      }
    }

    return SolverResult(substitutions: assumptions, weight: weight, errors: errors)
  }

  /// Solves an equality constraint.
  private mutating func solve(_ constraint: TypeEqualityConstraint) {
    let lhs = assumptions.get(for: constraint.t)
    let rhs = assumptions.get(for: constraint.u)

    // If the types are obviously equivalent, we're done.
    if lhs == rhs { return }

    switch (lhs, rhs) {
    case (let var_ as TypeVar, _):
      assumptions.set(substitution: rhs, for: var_)

    case (_, let var_ as TypeVar):
      assumptions.set(substitution: lhs, for: var_)

    case (let lty as FunType, let rty as FunType):
      // Function types never match if they have different domain lenghts.
      guard lty.dom.count == rty.dom.count else {
        errors.append(.incompatibleTypes(constraint))
        weight += ERROR_WEIGHT
        return
      }

      // Break the constraints.
      constraints.append(TypeEqualityConstraint(
        t: lty.codom.bareType,
        u: rty.codom.bareType,
        at: constraint.location + .codomain))

      for (i, params) in zip(lty.dom, rty.dom).enumerated() {
        let loc: ConstraintLocation = constraint.location + .parameter(i)

        // Make sure both parameters have the same label.
        if params.0.label != params.1.label {
          let cons = TypeEqualityConstraint(t: constraint.t, u: constraint.u, at: loc)
          errors.append(.incompatibleParameterLabels(cons))
          weight += ERROR_WEIGHT
        }

        constraints.append(TypeEqualityConstraint(
          t: params.0.type.bareType,
          u: params.1.type.bareType,
          at: constraint.location + .parameter(i)))
      }

    // case (let lty as BoundGenericType, _):

    default:
      errors.append(.incompatibleTypes(constraint))
      weight += ERROR_WEIGHT
    }
  }

  /// Solves a conformance constraint.
  private mutating func solve(_ constraint: TypeConformanceConstraint) {
    let lhs = assumptions.get(for: constraint.t)
    let rhs = assumptions.get(for: constraint.u)

    // If the types are obviously equivalent, we're done.
    if lhs == rhs { return }

    switch (lhs, rhs) {
    case is (TypeVar, TypeVar):
      // If both `T` and `U` are unknown, we can't solve the conformance constraint yet.
      constraints.insert(constraint, at: 0)

    case (_ as TypeVar, _):
      // If `T` is unknown and `U` is `Anything`, we postpone the constraint to see if we can
      // collect more information about `T`.
      guard rhs != context.anythingType else {
        constraints.insert(constraint, at: 0)
        return
      }

      // Otherwise, trying to unify it with `U` might be too broad. Instead, we have to compute the
      // "join" of both types. We do that by successiveky attempting to unify `T` with all types
      // known to be conforming to `U`.
      var builder = TypeConstraintDisjunctionBuilder()
      builder.add(TypeEqualityConstraint(t: lhs, u: rhs, at: constraint.location))

      for ty in context.getTypesConforming(to: rhs) {
        builder.add(TypeEqualityConstraint(t: lhs, u: ty, at: constraint.location), weight: 1)
      }

      constraints.append(builder.finalize())

    case (_, let var_ as TypeVar):
      // If only `U` is unknown, trying to unify it with `T` might be too specific. Instead, we
      // should compute the "meet" of both types. We do that by creating a set of assumptions that
      // each try to constraint `U` with a type to which `T` conforms.
      if lhs == context.anythingType {
        assumptions.set(substitution: lhs, for: var_)
      } else {
        // FIXME: Add conformed interfaces.
        var builder = TypeConstraintDisjunctionBuilder()
        builder.add(TypeEqualityConstraint(t: rhs, u: lhs, at: constraint.location))
        builder.add(
          TypeEqualityConstraint(t: rhs, u: context.anythingType, at: constraint.location),
          weight: 1)
        constraints.append(builder.finalize())
      }

      assumptions.set(substitution: lhs, for: var_)

    case (let lty as FunType, let rty as FunType):
      // Function types never match if they have different domain lenghts.
      guard lty.dom.count == rty.dom.count else {
        errors.append(.incompatibleTypes(constraint))
        weight += ERROR_WEIGHT
        return
      }

      // Break the constraints.
      constraints.append(TypeConformanceConstraint(
        t: lty.codom.bareType,
        u: rty.codom.bareType,
        at: constraint.location + .codomain))

      for (i, params) in zip(lty.dom, rty.dom).enumerated() {
        let loc: ConstraintLocation = constraint.location + .parameter(i)

        // Make sure both parameters have the same label.
        if params.0.label != params.1.label {
          let cons = TypeEqualityConstraint(t: constraint.t, u: constraint.u, at: loc)
          errors.append(.incompatibleParameterLabels(cons))
          weight += ERROR_WEIGHT
        }

        constraints.append(TypeConformanceConstraint(
          t: params.0.type.bareType,
          u: params.1.type.bareType,
          at: constraint.location + .parameter(i)))
      }

    case (_, context.anythingType):
      // All types trivially conform to `Anything`.
      break

    default:
      guard context.getTypesConforming(to: rhs).contains(lhs) else {
        errors.append(.incompatibleTypes(constraint))
        weight += ERROR_WEIGHT
        return
      }
    }
  }

  /// Sovles a specialization constraint.
  private mutating func solve(_ constraint: TypeSpecializationConstraint) {
    let lhs = constraint.t
    let rhs = assumptions.get(for: constraint.u)

    // If the types are obviously equivalent, we're done.
    if lhs == rhs { return }

    switch rhs {
    case is TypeVar:
      // If `U` is unknown, we can't solve the specialization constraint yet.
      constraints.insert(constraint, at: 0)

    case is FunType:
      // If both `T` and `U` are monomorphic, the constraint can be solved as an equality.
      constraints.append(TypeEqualityConstraint(t: lhs, u: rhs, at: constraint.location))

    case let rty as BoundGenericType where rty.type is FunType:
      // If `U` is a bound generic function type, the constraint can be solved as an equality
      // between `T` and `U` where each placeholder has been substituted.
      let monoTy = (rty.type as! FunType).subst(rty.bindings)
      constraints.append(TypeEqualityConstraint(t: lhs, u: monoTy, at: constraint.location))

    default:
      errors.append(.incompatibleTypes(constraint))
      weight += ERROR_WEIGHT
    }
  }

  /// Solves a value membership constraint.
  private mutating func solve(_ constraint: TypeValueMemberConstraint) {
    let owner = assumptions.get(for: constraint.u)

    // If the owning type is unknown, we can't solve the constraint yet.
    guard !(owner is TypeVar) else {
      constraints.insert(constraint, at: 0)
      return
    }

    // Look for the owner's declaration.
    guard let typeDecl = owner.decl as? NominalOrBuiltinTypeDecl else {
      errors.append(.noSuchValueMember(constraint))
      weight += ERROR_WEIGHT
      return
    }

    // Performs an unqualified lookup in the owning type declaration for the member's name.
    let decls = typeDecl
      .lookup(memberName: constraint.memberName, inCompilerContext: context)
      .compactMap { $0 as? LValueDecl }
    guard !decls.isEmpty  else {
      errors.append(.noSuchValueMember(constraint))
      weight += ERROR_WEIGHT
      return
    }

    let ownerBindings = (owner as? BoundGenericType)?.bindings ?? [:]
    var builder = TypeConstraintDisjunctionBuilder()
    for decl in decls {
      let placeholders = decl.type!.bareType.getUnboundPlaceholders()
      let bindings = ownerBindings.filter { placeholders.contains($0.key) }
      let memberTy = bindings.isEmpty
        ? decl.type!.bareType
        : context.getBoundGenericType(type: decl.type!.bareType, bindings: bindings)
      builder.add(TypeEqualityConstraint(t: constraint.t, u: memberTy, at: constraint.location))
    }
    constraints.append(builder.finalize())
  }

}
