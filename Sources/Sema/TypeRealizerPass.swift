import AST

/// A module pass that realizes the semantic types of type declarations and signatures.
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
      guard node.type == nil
        else { return }
      node.traverse(with: self)

      // If the declaration has an explicit annotation, use it to type the property, otherwise use
      // a fresh variable, qualified with `@cst`.
      if let sign = node.sign {
        node.type = sign.type!
      } else {
        node.type = context.getTypeVar()[.cst]
      }
    }

    func visit(_ node: FunDecl) {
      guard node.type == nil
        else { return }
      node.traverse(with: self)

      // Build the function's type.
      let placeholders = node.genericParams.map { $0.type as! TypePlaceholder }
      let dom = node.params.map { FunType.Param(label: $0.label, type: $0.type!) }
      let codom = node.codom?.type! ?? context.nothingType[.cst]

      if node.kind == .regular {
        node.type = context.getFunType(placeholders: placeholders, dom: dom, codom: codom)[.cst]
        return
      }

      assert(node.kind ~= [.method, .constructor, .destructor], "bad function kind")

      // If the function's declared in a type declaration, we need to retrieve `Self`'s type.
      assert(node.declContext != nil, "member function declared outside of a type declaration")
      let selfTypeDecls = node.declContext!
        .lookup(unqualifiedName: "Self", inCompilerContext: context)
      guard let selfTypeDecl = selfTypeDecls.first as? TypeDecl else {
        node.type = context.errorType[.cst]
        return
      }

      if selfTypeDecl.type == nil {
        selfTypeDecl.accept(visitor: self)
        assert(selfTypeDecl.type != nil)
      }
      let bareSelfTy = selfTypeDecl.type!
      let qualSelfTy = (node.kind != .method) || node.isMutating
        ? bareSelfTy[.mut]
        : bareSelfTy[.cst]

      let selfValueDecl = node.decls.first { ($0 as? PropDecl)?.name == "self" }
      assert(selfValueDecl != nil, "missing `self` declaration")
      (selfValueDecl as! PropDecl).type = qualSelfTy

      if node.kind == .constructor {
        // A constructor's codomain is always `Self`, so we can ignore the node's codomain.
        node.type = context.getFunType(dom: dom, codom: qualSelfTy)[.cst]
      } else if node.kind ~= [.method, .destructor] {
        // Methods and constructor have signatures of the form `Self -> Domain -> Codomain`.
        let funTy = context.getFunType(dom: dom, codom: codom)
        let mtdTy = context.getFunType(
          placeholders: placeholders,
          dom: [FunType.Param(label: nil, type: qualSelfTy)],
          codom: funTy[.cst])

        node.type = mtdTy[.cst]
      } else {
        assertionFailure("bad function")
      }
    }

    func visit(_ node: GenericParamDecl) {
      guard node.type == nil
        else { return }
      node.type = context.getTypePlaceholder(decl: node)
    }

    func visit(_ node: ParamDecl) {
      guard node.type == nil
        else { return }
      node.traverse(with: self)

      // If the declaration has an explicit annotation, use it to type the property, otherwise use
      // a fresh variable, qualified with `@cst`.
      if let sign = node.sign {
        node.type = sign.type!
      } else {
        node.type = context.getTypeVar()[.cst]
      }
    }

    func visit(_ node: InterfaceDecl) {
      guard node.type == nil
        else { return }

      node.type = context.getInterfaceType(decl: node)
      node.traverse(with: self)
    }

    func visit(_ node: StructDecl) {
      guard node.type == nil
        else { return }

      node.type = context.getStructType(decl: node)
      node.traverse(with: self)
    }

    func visit(_ node: UnionDecl) {
      guard node.type == nil
        else { return }

      node.type = context.getUnionType(decl: node)
      node.traverse(with: self)
    }

    func visit(_ node: QualTypeSign) {
      node.traverse(with: self)

      // Notice that we do not add any default qualifier at this point, so that empty qualifier
      // sets can be used to designate unspecified placehoder qualifiers. This allows generic types
      // to be specialized with different placeholders.

      // Build the signature's qualified type.
      let bareType = node.sign != nil
        ? node.sign!.type!
        : context.getTypeVar()
      node.type = QualType(bareType: bareType, qualDecls: node.quals)
    }

    func visit(_ node: IdentSign) {
      // Resolve the specialization arguments, if any.
      var specArgs: [String: QualType] = [:]
      for (name, sign) in node.specArgs {
        sign.accept(visitor: self)
        specArgs[name] = sign.type
      }

      // Since types identifiers are not overloadable, the corresponding type declaration should
      // have been resolved during name binding.
      guard let decl = node.referredDecl else {
        node.type = context.errorType
        return
      }

      // Realize the declaration's type if necessary.
      if decl.type == nil {
        decl.accept(visitor: self)
        assert(decl.type != nil)
      }

      // FIXME: Check for superfluous specialization arguments later.

      if decl.type!.canBeOpened {
        // Check for superfluous specialization arguments.
        let placeholders = decl.type!.getUnboundPlaceholders()
        let superfluous = Set(specArgs.keys).subtracting(placeholders.map({ $0.name }))
        for name in superfluous {
          node.registerWarning(message: Issue.superfluousSpecArg(name: name))
        }

        // Preserve the specialization arguments in a bound generic type.
        let bindings = Dictionary(uniqueKeysWithValues: placeholders.map {
          ($0, specArgs[$0.name] ?? QualType(bareType: context.getTypeVar(), quals: []))
        })
        node.type = context.getBoundGenericType(type: decl.type!, bindings: bindings)
      } else {
        // If the referred type can't be opened, all specialization arguments are superfluous.
        for name in specArgs.keys {
          node.registerError(message: Issue.superfluousSpecArg(name: name))
        }

        node.type = decl.type!
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
      let codom = node.codom?.type! ?? context.nothingType[.cst]
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
