import AST

final class TypeConstraintExtractor: ASTVisitor {

  /// The compiler context.
  let context: CompilerContext

  /// The extracted type constraints.
  var constraints: [TypeConstraint] = []

  /// The type of the function declaration being visited (if any).
  var visitedFunType: FunType?

  init(context: CompilerContext) {
    self.context = context
  }

  func visit(_ node: PropDecl) {
    if let (_, value) = node.initializer {
      value.accept(visitor: self)
      let loc: ConstraintLocation = .location(node, .initializer)
      let cons: TypeConstraint = node.sign?.sign != nil
        ? TypeConformanceConstraint(t: value.type!.bareType, u: node.type!.bareType, at: loc)
        : TypeEqualityConstraint(t: value.type!.bareType, u: node.type!.bareType, at: loc)
      constraints.append(cons)
    }
  }

  func visit(_ node: FunDecl) {
    let lastVisitedFunType = visitedFunType
    visitedFunType = (node.type!.bareType as! FunType)
    node.traverse(with: self)
    visitedFunType = lastVisitedFunType
  }

  func visit(_ node: ParamDecl) {
    if let value = node.defaultValue {
      value.accept(visitor: self)
      let loc: ConstraintLocation = .location(node, .initializer)
      let cons: TypeConstraint = node.sign?.sign != nil
        ? TypeConformanceConstraint(t: value.type!.bareType, u: node.type!.bareType, at: loc)
        : TypeEqualityConstraint(t: value.type!.bareType, u: node.type!.bareType, at: loc)
      constraints.append(cons)
    }
  }

  func visit(_ node: NullExpr) {
    node.type = context.anythingType.cst
  }

  func visit(_ node: LambdaExpr) {
    node.traverse(with: self)

    // Build the function's type.
    let dom = node.params.map { FunType.Param(label: $0.label, type: $0.type!) }
    let codom = node.codom?.type! ?? context.getTypeVar().cst
    let funTy = context.getFunType(dom: dom, codom: codom)

    node.type = QualType(bareType: funTy, quals: [])
  }

  func visit(_ node: UnsafeCastExpr) {
    node.traverse(with: self)
    node.type = QualType(bareType: node.castSign.type!, quals: node.operand.type!.quals)
  }

  func visit(_ node: InfixExpr) {
    node.lhs.accept(visitor: self)
    node.rhs.accept(visitor: self)

    // Infix operators are implemented as methods of the left operand. Hence they have a type of
    // the form `(_: RHS) -> T`, where `RHS` is some type variable, and `T` is the type of the
    // infix expression.
    node.type = QualType(bareType: context.getTypeVar(), quals: [])
    let rhsTy = QualType(bareType: context.getTypeVar(), quals: [])
    let funTy = context.getFunType(dom: [FunType.Param(type: rhsTy)], codom: node.type!)
    node.op.type = funTy.cst

    // The type of the right operand should conform to the argument of the operator's type.
    constraints.append(TypeConformanceConstraint(
      t: node.rhs.type!.bareType,
      u: rhsTy.bareType,
      at: .location(node, .infixRHS)))

    // The type of the left operand should have a method named after the operator, with the same
    // signature as that of the operator.
    constraints.append(TypeValueMemberConstraint(
      t: node.op.type!.bareType,
      u: node.lhs.type!.bareType,
      memberName: node.op.name,
      at: .location(node, .infixOp)))
  }

  func visit(_ node: PrefixExpr) {
    node.operand.accept(visitor: self)

    // Prefix operators are implemented as methods of their operand. Hence they have a type of
    // the form `() -> T`, where `T` is the type of the prefix expression.
    node.type = QualType(bareType: context.getTypeVar(), quals: [])
    let funTy = context.getFunType(dom: [], codom: node.type!)
    node.op.type = funTy.cst

    // The type of the left operand should have a method named after the operator, with the same
    // signature as that of the operator.
    constraints.append(TypeValueMemberConstraint(
      t: node.op.type!.bareType,
      u: node.operand.type!.bareType,
      memberName: node.op.name,
      at: .location(node, .infixOp)))
  }

  func visit(_ node: CallExpr) {
    node.traverse(with: self)

    // Build the supposed type of the callee. Note the use of fresh variables so as to loosen the
    // constraints on the arguments.
    let dom = node.args.map {
      FunType.Param(label: $0.label, type: QualType(bareType: context.getTypeVar(), quals: []))
    }
    node.type = QualType(bareType: context.getTypeVar(), quals: [])
    let funTy = context.getFunType(dom: dom, codom: node.type!)

    // Create a specialization constraint between the callee and the function type we've built.
    let loc: ConstraintLocation = .location(node, .call)
    constraints.append(TypeSpecializationConstraint(
      t: funTy,
      u: node.callee.type!.bareType,
      at: loc))

    // Create a conformance constraint for each argument.
    for (i, (arg, param)) in zip(node.args, funTy.dom).enumerated() {
      constraints.append(TypeConformanceConstraint(
        t: arg.type!.bareType,
        u: param.type.bareType,
        at: loc + .parameter(i)))
    }
  }

  func visit(_ node: CallArgExpr) {
    node.traverse(with: self)
    node.type = node.value.type!
  }

  func visit(_ node: IdentExpr) {
    // Handle binding operators.
    if [":=", "&-", "<-"].contains(node.name) {
      node.type = context.assignmentType
      return
    }

    node.traverse(with: self)

    // To resolve overloading, identifiers are typed with fresh variables, and a disjunction of
    // constraints is created for each referred location computed during name binding.
    guard !node.referredDecls.isEmpty else {
      node.type = context.errorType.cst
      return
    }

    let identTy = context.getTypeVar()
    node.type = QualType(bareType: identTy, quals: [])

    // Build the set of constraints related to the referred location.
    var builder = TypeConstraintDisjunctionBuilder()
    let loc: ConstraintLocation = .location(node, .identifier)
    for decl in node.referredDecls {
      switch decl {
      case let valueDecl as LValueDecl:
        var valueTy = valueDecl.type!.bareType
        if valueTy.canBeOpened {
          // Preserve the specialization arguments in a bound generic type.
          let placeholders = valueTy.getUnboundPlaceholders()
          let bindings = Dictionary(uniqueKeysWithValues: placeholders.map {
            ($0, node.specArgs[$0.name]?.type
              ?? QualType(bareType: context.getTypeVar(), quals: []))
          })
          valueTy = context.getBoundGenericType(type: valueTy, bindings: bindings)
        }

        builder.add(TypeEqualityConstraint(t: identTy, u: valueTy, at: loc))

      case let typeDecl as TypeDecl:
        var typeTy = typeDecl.type!
        if typeTy.canBeOpened {
          // Preserve the specialization arguments in a bound generic type.
          let placeholders = typeTy.getUnboundPlaceholders()
          let bindings = Dictionary(uniqueKeysWithValues: placeholders.map {
            ($0, node.specArgs[$0.name]?.type
              ?? QualType(bareType: context.getTypeVar(), quals: []))
          })
          typeTy = context.getBoundGenericType(type: typeTy, bindings: bindings)
        }

        // As nominal type identifiers may be used as function identifiers, a membership constraint
        // for possible constructors has to be created, in addition to the equality constraint on
        // the type's kind. Notice that the membership constraint is created first, as identifiers
        // are more likely to represent constructors than first-class types.
        builder.add(TypeValueMemberConstraint(t: identTy, u: typeTy, memberName: "new", at: loc))
        builder.add(TypeEqualityConstraint(t: identTy, u: typeTy, at: loc))

      default:
        assertionFailure("bad declaration")
      }
    }

    constraints.append(builder.finalize())
  }

  func visit(_ node: SelectExpr) {
    node.owner.accept(visitor: self)

    // The declaration referred by the ownee depends on the owner's type, and so it cannot be
    // visited as a regular identifier. Instead, we create a membership constraint.
    node.ownee.type = QualType(bareType: context.getTypeVar(), quals: [])
    node.type = node.ownee.type!
    constraints.append(TypeValueMemberConstraint(
      t: node.ownee.type!.bareType,
      u: node.owner.type!.bareType,
      memberName: node.ownee.name,
      at: .location(node, .select)))
  }

  func visit(_ node: ImplicitSelectExpr) {
    // Owners of a select expression can be omitted only if its ownee has the same type. Hence we
    // can create a membership constraint on the ownee's type.
    node.ownee.type = QualType(bareType: context.getTypeVar(), quals: [])
    node.type = node.ownee.type
    constraints.append(TypeValueMemberConstraint(
      t: node.ownee.type!.bareType,
      u: node.ownee.type!.bareType,
      memberName: node.ownee.name,
      at: .location(node, .select)))
  }

  func visit(_ node: ArrayLitExpr) {
    fatalError("not implemented")
  }

  func visit(_ node: SetLitExpr) {
    fatalError("not implemented")
  }

  func visit(_ node: MapLitExpr) {
    fatalError("not implemented")
  }

  func visit(_ node: BoolLitExpr) {
    node.type = context.getBuiltinType(.bool).cst
  }

  func visit(_ node: IntLitExpr) {
    node.type = context.getBuiltinType(.int).cst
  }

  func visit(_ node: FloatLitExpr) {
    node.type = context.getBuiltinType(.float).cst
  }

  func visit(_ node: StrLitExpr) {
    node.type = context.getBuiltinType(.string).cst
  }

  func visit(_ node: ParenExpr) {
    node.traverse(with: self)
    node.type = node.expr.type
  }

  func visit(_ node: InvalidExpr) {
    node.type = QualType(bareType: context.errorType, quals: [])
  }

  func visit(_ node: BindingStmt) {
    node.lvalue.accept(visitor: self)
    node.rvalue.accept(visitor: self)
    constraints.append(TypeConformanceConstraint(
      t: node.rvalue.type!.bareType,
      u: node.lvalue.type!.bareType,
      at: .location(node, .binding)))
  }

  func visit(_ node: ReturnStmt) {
    if let (_, value) = node.binding {
      value.accept(visitor: self)
      constraints.append(TypeConformanceConstraint(
        t: value.type!.bareType,
        u: visitedFunType!.codom.bareType,
        at: .location(node, .return)))
    }
  }

}
