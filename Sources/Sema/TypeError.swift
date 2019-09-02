import AST

enum TypeError {

  case ambiguousConstraint(TypeConstraintDisjunction)
  case incompatibleTypes(TypeConstraint)
  case incorrectParameterLabel(TypeConstraint)
  case irreducibleConstraint(TypeConstraint)
  case noSuchValueMember(TypeValueMemberConstraint)

  // MARK:- Error diagnostics generation

  func register(withTypeFinalizer finalizer: TypeFinalizer) {
    switch self {
    case .ambiguousConstraint:
      break

    case .incompatibleTypes(let constraint):
      let node = resolveLocation(constraint)

      // Extract the pair of incompatible types.
      let t, u: TypeBase
      switch constraint {
      case let cons as TypeEqualityConstraint:
        t = cons.t.accept(transformer: finalizer)
        u = cons.u.accept(transformer: finalizer)
      case let cons as TypeConformanceConstraint:
        t = cons.t.accept(transformer: finalizer)
        u = cons.u.accept(transformer: finalizer)
      default:
        node.registerError(message: "incompatible types")
        return
      }

      // Produce the most accurate message possible, based on the constraint's location.
      switch constraint.location.path.last! {
      case .binding, .initializer:
        node.registerError(message: "cannot assign value of type '\(t)' to r-value of type '\(u)'")

      case .infixOp:
        guard let expr = constraint.location.anchor as? InfixExpr
          else { break }
        node.registerError(message:
         "operator '\(expr.op.name)' cannot be applied to operands of type '\(u)' and '\(t)'")

      default:
        node.registerError(message: "type '\(t)' is not equal to '\(u)'")
      }

    case .incorrectParameterLabel(let constraint):
      let node = resolveLocation(constraint)

      // Attempt to retrieve the expected and found parameters.
      if let call = constraint.location.anchor as? CallExpr,
        let arg = node as? CallArgExpr,
        let calleeTy = call.callee.type!.bareType.accept(transformer: finalizer) as? FunType,
        case .parameter(let i) = constraint.location.path.last!
      {
        let expected = calleeTy.dom[i].label ?? ""
        let found = arg.label ?? ""
        node.registerError(message:
          "incorrect parameter label, expected '\(expected)' but found '\(found)'")
      }

      // Fallback on a more generic diganostic.
      node.registerError(message: "incompatible parameter labels")

    case .irreducibleConstraint(let constraint):
      // FIXME: These should probably be silenced, as they are likely caused by an error that
      // occurred before type inference.
      let node = resolveLocation(constraint)
      node.registerWarning(message: "unsolvable type constraint: '\(constraint)'")

    case .noSuchValueMember(let constraint):
      let node = resolveLocation(constraint)
      let ownerTy = constraint.u.accept(transformer: finalizer)
      node.registerError(message:
        "value of type '\(ownerTy)' has no member '\(constraint.memberName)'")
    }
  }

  private func resolveLocation(_ constraint: TypeConstraint) -> ASTNode {
    var node = constraint.location.anchor
    for component in constraint.location.path {
      switch component {
      case .call, .codomain, .identifier:
        continue

      case .binding:
        switch node {
        case let stmt as BindingStmt:
          node = stmt.rvalue
        case let expr as CallArgExpr:
          node = expr.value
        default:
          return node
        }

      case .condition:
        switch node {
        case let stmt as IfStmt:
          node = stmt.condition
        case let stmt as WhileStmt:
          node = stmt.condition
        default:
          return node
        }

      case .infixOp:
        guard let expr = node as? InfixExpr
          else { return node }
        node = expr.op

      case .infixRHS:
        guard let expr = node as? InfixExpr
          else { return node }
        node = expr.rhs

      case .initializer:
        switch node {
        case let decl as PropDecl:
          guard let initializer = decl.initializer
            else { return node }
          node = initializer.value

        case let decl as ParamDecl:
          guard let defaultValue = decl.defaultValue
            else { return node }
          node = defaultValue

        default:
          return node
        }

      case .parameter(let i):
        guard let expr = node as? CallExpr
          else { return node }
        node = expr.args[i]

      case .prefixOp:
        guard let expr = node as? PrefixExpr
          else { return node }
        node = expr.op

      case .return:
        guard let stmt = node as? ReturnStmt
          else { return node }
        guard let binding = stmt.binding
          else { return node }
        node = binding.value

      case .select:
        switch node {
        case let expr as SelectExpr:
          node = expr.ownee
        case let expr as ImplicitSelectExpr:
          node = expr.ownee
        default:
          return node
        }
      }
    }

    return node
  }

}
