import AST

/// A module pass that binds identifiers to their declaration contexts.
///
/// This pass takes place immediately after parsing, and links value and type identifiers to their
/// declarations. Because of overloading, determining the declaration node to which an identifier
/// refers might have to be delayed until after type inference completes.
public struct NameBinderPass {

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
    let binder = Binder(topLevelDeclContext: module, context: context)
    for decl in module.decls {
      decl.accept(visitor: binder)
    }
  }

  // MARK: Internal visitor

  private final class Binder: ASTVisitor {

    /// The compiler context.
    let context: CompilerContext

    /// An array that keeps track of the property or parameter declaration being visited
    ///
    /// This array keeps track of the property and parameter declarations being being visited while
    /// resolving the declaration context of the identifiers in their initializer or default value.
    /// Consider for instance the following Anzen program:
    ///
    /// ```anzen
    /// let x <- 0
    /// fun f() { let x <- x }
    /// ```
    ///
    /// The identifier `x` inside function `f` should be bound to the outermost declaration rather
    /// than that in `f`'s body.
    var declBeingVisited: Set<ObjectIdentifier> = []

    /// The current declaration context.
    var currentDeclContext: DeclContext

    init(topLevelDeclContext: Module, context: CompilerContext) {
      self.context = context
      self.currentDeclContext = topLevelDeclContext
    }

    func visit(_ node: PropDecl) {
      declBeingVisited.insert(ObjectIdentifier(node))
      node.traverse(with: self)
      declBeingVisited.remove(ObjectIdentifier(node))
    }

    func visit(_ node: FunDecl) {
      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

    func visit(_ node: ParamDecl) {
      // Parameters are considered declared all at once. Hence, all adjacent parameter declarations
      // are added to the set of visited declarations.
      let paramDeclIDs = node.declContext!.decls.compactMap {
        ($0 as? ParamDecl).map(ObjectIdentifier.init)
      }

      declBeingVisited.formUnion(paramDeclIDs)
      node.traverse(with: self)
      declBeingVisited.subtract(paramDeclIDs)
    }

    func visit(_ node: InterfaceDecl) {
      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

    func visit(_ node: StructDecl) {
      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

    func visit(_ node: UnionDecl) {
      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

    func visit(_ node: TypeExtDecl) {
      inDeclContext(node) {
        node.body.accept(visitor: self)
      }
    }

    func visit(_ node: PrefixExpr) {
      // The declaration context of the expression's operator determined before type inference.
      node.operand.accept(visitor: self)
    }

    func visit(_ node: InfixExpr) {
      // The declaration context of the expression's operator determined before type inference.
      node.lhs.accept(visitor: self)
      node.rhs.accept(visitor: self)
    }

    func visit(_ node: IdentExpr) {
      let decls = currentDeclContext.lookup(unqualifiedName: node.name, inCompilerContext: context)
      if decls.isEmpty {
        node.registerError(message: Issue.unboundIdentifier(name: node.name))
      } else {
        node.referredDecls = decls
      }

      node.traverse(with: self)
    }

    func visit(_ node: SelectExpr) {
      // The declaration context of a select's ownee cannot be determined before type inference.
      node.owner.accept(visitor: self)
    }

    func visit(_ node: ImplicitSelectExpr) {
      // The declaration context of a select's ownee cannot be determined before type inference.
    }

    func visit(_ node: BraceStmt) {
      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

    func visit(_ node: IdentSign) {
      let decls = currentDeclContext.lookup(unqualifiedName: node.name, inCompilerContext: context)
      if decls.isEmpty {
        node.registerError(message: Issue.unboundIdentifier(name: node.name))
      } else if !(decls[0] is TypeDecl) {
        node.registerError(message: Issue.invalidTypeIdentifier(name: node.name))
      } else {
        assert(decls.count == 1, "bad extension on overloaded type name")
        node.referredDecl = (decls[0] as! NamedTypeDecl)
      }

      node.traverse(with: self)
    }

    func visit(_ node: NestedIdentSign) {
      node.owner.accept(visitor: self)
    }

    func visit(_ node: ImplicitNestedIdentSign) {
    }

    // MARK: Helpers

    private func inDeclContext(_ declContext: DeclContext, run block: () -> Void) {
      let previousDeclContext = currentDeclContext
      currentDeclContext = declContext
      block()
      currentDeclContext = previousDeclContext
    }

  }

}
