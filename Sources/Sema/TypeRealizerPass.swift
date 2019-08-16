import AST

/// A module pass that realizes the semantic types of all type declarations.
public struct TypeRealizerPass {

  /// The compiler context.
  public let context: CompilerContext

  /// The module being processed.
  public let module: Module

  public init(module: Module, context: CompilerContext) {
    assert(module.state == .parsed, "module has not been parsed yet")
    self.context = context
    self.module = module
  }

  public func process() {
    let realizer = Realizer(context: context)
    for decl in module.decls {
      decl.accept(visitor: realizer)
    }
  }

  // MARK: Internal visitor

  private final class Realizer: ASTVisitor {

    /// The compiler context.
    let context: CompilerContext

    init(context: CompilerContext) {
      self.context = context
    }

    func visit(_ node: PropDecl) {
      assert(node.type == nil, "declaration's type already realized")
      node.traverse(with: self)

      // If the declaration has an explicit annotation, use it to type the property, otherwise use
      // a fresh variable, qualified with `@cst`.
      if let sign = node.sign {
        node.type = sign.type!
      } else {
        node.type = context.getTypeVar().cst
      }
    }

    func visit(_ node: FunDecl) {
      assert(node.type == nil, "declaration's type already realized")
      node.traverse(with: self)

      // Build the function's type.
      let dom = node.params.map { FunType.Param(label: $0.label, type: $0.type!) }
      let codom = node.codom?.type! ?? context.nothingType.cst
      let funTy = context.getFunType(
        genericParams: node.genericParams.map { $0.type as! TypePlaceholder },
        dom: dom,
        codom: codom)

      node.type = funTy.cst
    }

    func visit(_ node: GenericParamDecl) {
      assert(node.type == nil, "declaration's type already realized")
      node.type = context.getTypePlaceholder(decl: node)
    }

    func visit(_ node: ParamDecl) {
      assert(node.type == nil, "declaration's type already realized")
      node.traverse(with: self)

      // If the declaration has an explicit annotation, use it to type the property, otherwise use
      // a fresh variable, qualified with `@cst`.
      if let sign = node.sign {
        node.type = sign.type!
      } else {
        node.type = context.getTypeVar().cst
      }
    }

    func visit(_ node: InterfaceDecl) {
      assert(node.type == nil, "declaration's type already realized")
      node.traverse(with: self)
      node.type = context.getInterfaceType(decl: node)
    }

    func visit(_ node: StructDecl) {
      assert(node.type == nil, "declaration's type already realized")
      node.traverse(with: self)
      node.type = context.getStructType(decl: node)
    }

    func visit(_ node: UnionDecl) {
      assert(node.type == nil, "declaration's type already realized")
      node.traverse(with: self)
      node.type = context.getUnionType(decl: node)
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
      node.traverse(with: self)
      node.type = QualType(bareType: context.getTypeVar(), quals: [])
    }

    func visit(_ node: PrefixExpr) {
      node.traverse(with: self)
      node.type = QualType(bareType: context.getTypeVar(), quals: [])
    }

    func visit(_ node: CallExpr) {
      node.traverse(with: self)
      node.type = QualType(bareType: context.getTypeVar(), quals: [])
    }

    func visit(_ node: CallArgExpr) {
      node.traverse(with: self)
      node.type = QualType(bareType: context.getTypeVar(), quals: [])
    }

    func visit(_ node: IdentExpr) {
      node.traverse(with: self)
      node.type = QualType(bareType: context.getTypeVar(), quals: [])
    }

    func visit(_ node: SelectExpr) {
      node.traverse(with: self)
      node.type = node.ownee.type
    }

    func visit(_ node: ImplicitSelectExpr) {
      node.traverse(with: self)
      node.type = node.ownee.type
    }

    func visit(_ node: ArrayLitExpr) {
      node.traverse(with: self)
      node.type = QualType(bareType: context.getTypeVar(), quals: [])
    }

    func visit(_ node: SetLitExpr) {
      node.traverse(with: self)
      node.type = QualType(bareType: context.getTypeVar(), quals: [])
    }

    func visit(_ node: MapLitExpr) {
      node.traverse(with: self)
      node.type = QualType(bareType: context.getTypeVar(), quals: [])
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

    func visit(_ node: QualTypeSign) {
      node.traverse(with: self)

      // Add the default `@cst` qualifier if necessary.
      let quals = node.quals.isEmpty
        ? [.cst]
        : node.quals

      // Build the signature's qualified type.
      let bareType = node.sign != nil
        ? node.sign!.type!
        : context.getTypeVar()
      node.type = QualType(bareType: bareType, quals: quals)
    }

    func visit(_ node: IdentSign) {
      // Since types identifiers are not overloadable, the corresponding type declaration should
      // have been resolved during name binding.

      if let decl = node.referredDecl {
        // Realize the declaration's type if necessary.
        if decl.type == nil {
          decl.accept(visitor: self)
          assert(decl.type != nil)
        }

        let placeholders = decl.type!.getUnboundPlaceholders()
        if placeholders.isEmpty {
          node.type = decl.type!
        } else {
          // Open the unbound placeholders.
          let bindings = Dictionary(
            uniqueKeysWithValues: placeholders.map { ($0, context.getTypeVar()) })
          node.type = context.getBoundGenericType(type: decl.type!, bindings: bindings)
        }
      }
    }

    func visit(_ node: NestedIdentSign) {
      node.owner.accept(visitor: self)
      node.ownee.type = context.getTypeVar()
      node.type = node.ownee.type
    }

    func visit(_ node: ImplicitNestedIdentSign) {
      node.ownee.type = context.getTypeVar()
      node.type = node.ownee.type
    }

    func visit(_ node: FunSign) {
      node.traverse(with: self)
      let dom = node.params.map { FunType.Param(label: $0.label, type: $0.type!) }
      let codom = node.codom?.type! ?? context.nothingType.cst
      node.type = context.getFunType(dom: dom, codom: codom)
    }

    func visit(_ node: ParamSign) {
      node.sign.accept(visitor: self)
      node.type = node.sign.type!
    }

    func visit(_ node: InvalidSign) {
      node.type = context.errorType
    }

  }

}
