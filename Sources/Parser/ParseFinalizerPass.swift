import AST
import Utils

/// An AST pass that finalizes the construction of a parsed AST.
///
/// Once the module's AST has been parsed, this pass walks all top-level declarations to link named
/// declarations to their declaration context, and check that the AST is "well-formed" with respect
/// to Anzen's grammar.
///
/// Well-formedness:
/// ================
///
/// The parser intentionally accepts a superset of Anzen's grammar, so as to reduce the complexity
/// of its internal state. Consequently, some syntax errors are not caught during parsing, and
/// must be found with this pass, so as to verify that all AST invariants hold.
///
/// Lexical scoping:
/// ================
///
/// Named declarations (e.g. instances of `PropDecl`) have to be associated with a corresponding
/// declaration context (i.e. the lexical region in which named entities are "visible").
///
/// Note that duplicate named declarations are not added to their declaring context. Consequently,
/// named declaration whose `declContext` property is `nil` after finalization must not be
/// considered to resolve identifiers during semantic analysis.
public struct ParseFinalizerPass {

  /// The module being processed.
  public let module: Module

  public init(module: Module) {
    self.module = module
  }

  public func process() {
    let finalizer = Finalizer(module: module)
    for decl in module.decls {
      decl.accept(visitor: finalizer)
    }
  }

  // MARK: Internal visitor

  private final class Finalizer: ASTVisitor {

    /// The current declaration context.
    var currentDeclContext: DeclContext

    init(module: Module) {
      self.currentDeclContext = module
    }

    func visit(_ node: MainCodeDecl) {
      node.module.children.append(node)
      currentDeclContext = node
      node.traverse(with: self)
      currentDeclContext = node.module
    }

    func visit(_ node: PropDecl) {
      // Check for invalid attributes.
      for attr in node.attrs {
        attr.registerWarning(message: Issue.unexpectedPropAttr(attr: attr))
      }

      // Check for invalid modifiers.
      if !(currentDeclContext is NominalTypeDecl || currentDeclContext is TypeExtDecl) {
        for modifier in node.modifiers {
          modifier.registerError(message: Issue.unexpectedDeclModifier(modifier: modifier))
        }
      }

      if unsureUniquelyDeclared(node) {
        finalizeNamedDecl(node)
      }
    }

    func visit(_ node: FunDecl) {
      // Check for invalid attributes.
      for attr in node.attrs where attr.name != "@air_name" {
        attr.registerWarning(message: Issue.unexpectedFunAttr(attr: attr))
      }

      // Check for invalid modifiers.
      if !(currentDeclContext is NominalTypeDecl || currentDeclContext is TypeExtDecl) {
        for modifier in node.modifiers {
          modifier.registerError(message: Issue.unexpectedDeclModifier(modifier: modifier))
        }
      }

      // Check for invalid redeclarations. Since function names are overloadable, a redeclaration
      // is invalid only if the previously declared entity isn't another function declaration.
      var isUniquelyDeclared = true
      for sibling in currentDeclContext.decls {
        if let decl = sibling as? NamedDecl,
          (decl !== node) && (decl.name != "") && (decl.name == node.name) && !(decl is FunDecl)
        {
          node.registerError(message: Issue.invalidRedeclaration(name: node.name))
          isUniquelyDeclared = false
          break
        }
      }

      // Make sure all parameters have a type signature.
      for param in node.params where param.sign == nil {
        param.registerError(message: Issue.missingParamSign())
      }

      if isUniquelyDeclared {
        finalizeNamedContext(node)
      }
    }

    func visit(_ node: GenericParamDecl) {
      if unsureUniquelyDeclared(node) {
        finalizeNamedDecl(node)
      }
    }

    func visit(_ node: ParamDecl) {
      if unsureUniquelyDeclared(node) {
        finalizeNamedDecl(node)
      }
    }

    func visit(_ node: InterfaceDecl) {
      if unsureUniquelyDeclared(node) {
        finalizeNamedContext(node)
      }
    }

    func visit(_ node: StructDecl) {
      if unsureUniquelyDeclared(node) {
        finalizeNamedContext(node)
      }
    }

    func visit(_ node: UnionDecl) {
      if unsureUniquelyDeclared(node) {
        finalizeNamedContext(node)
      }
    }

    func visit(_ node: TypeExtDecl) {
      currentDeclContext.decls.append(node)
      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

    func visit(_ node: BraceStmt) {
      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

    // MARK: Helpers

    private func unsureUniquelyDeclared(_ node: NamedDecl) -> Bool {
      for sibling in currentDeclContext.decls {
        if let decl = sibling as? NamedDecl,
          (decl !== node) && (decl.name != "") && (decl.name == node.name)
        {
          node.registerError(message: Issue.invalidRedeclaration(name: node.name))
          return false
        }
      }
      return true
    }

    private func inDeclContext(_ declContext: DeclContext, run block: () -> Void) {
      let previousDeclContext = currentDeclContext
      currentDeclContext = declContext
      block()
      currentDeclContext = previousDeclContext
    }

    private func finalizeNamedDecl<Node>(_ node: Node) where Node: NamedDecl {
      currentDeclContext.decls.append(node)
      node.declContext = currentDeclContext
      node.traverse(with: self)
    }

    private func finalizeNamedContext<Node>(_ node: Node) where Node: NamedDecl & DeclContext {
      currentDeclContext.decls.append(node)
      node.declContext = currentDeclContext
      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

  }

}
