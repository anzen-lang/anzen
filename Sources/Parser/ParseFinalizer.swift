import AST
import Utils

/// An AST pass that finalizes the construction of a parsed AST.
///
/// This pass has two tasks:
/// 1. Annotate the AST with information related to lexical scoping. the creation of the AST.
/// 2. Report syntax errors that were not detected during
///
/// # Lexical scoping:
///
/// Named declarations (e.g. instances of `PropDecl`) have to be associated with a declaration
/// context, denoting a lexical region that delimits the "visibility" of a named entity.
///
/// Note that duplicate named declarations are not added to their declaring context. Consequently,
/// named declaration whose `declContext` property is `nil` after finalization must not be
/// considered to resolve identifiers during semantic analysis.
///
/// # Additional syntax errors:
///
/// The parser intentionally accepts a superset of Anzen's grammar, so as to reduce the complexity
/// of its internal state. Consequently, some syntax errors are not caught during parsing, and
/// must be found by this visitor.
public struct ParseFinalizer {

  /// The module being processed.
  public let module: Module

  public init(module: Module) {
    self.module = module
  }

  public func process() {
    let finalizer = FinalizerVisitor(module: module)
    for decl in module.decls {
      decl.accept(visitor: finalizer)
    }
  }

  // MARK: Internal visitor

  private class FinalizerVisitor: ASTVisitor {

    /// The module being processed.
    let module: Module
    /// The current declaration context.
    var currentDeclContext: DeclContext

    init(module: Module) {
      self.module = module
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
        attr.registerWarning(
          message: "unexpected attribute '\(attr.name)' on property declaration will be ignored")
      }

      // Check for invalid modifiers.
      if !(currentDeclContext is NominalTypeDecl) {
        for modifier in node.modifiers {
          modifier.registerError(
            message: "modifier '\(modifier.kind)' may only appear in type declaration")
        }
      }

      if unsureUniquelyDeclared(node) {
        finalizeNamedDecl(node)
      }
    }

    func visit(_ node: FunDecl) {
      // Check for invalid attributes.
      for attr in node.attrs where attr.name != "@air_name" {
        attr.registerWarning(
          message: "unexpected attribute '\(attr.name)' on function declaration will be ignored")
      }

      // Check for invalid modifiers.
      if !(currentDeclContext is NominalTypeDecl) {
        for modifier in node.modifiers {
          modifier.registerError(
            message: "modifier '\(modifier.kind)' may only appear in type declaration")
        }
      }

      // Check for invalid redeclarations. Since function names are overloadable, a redeclaration
      // is invalid only if the previously declared entity isn't another function declaration.
      var isUniquelyDeclared = true
      for sibling in currentDeclContext.decls {
        if let decl = sibling as? NamedDecl,
          (decl !== node) && (decl.name != "") && (decl.name == node.name) && !(decl is FunDecl)
        {
          node.registerError(message: "invalid redeclaration of '\(node.name)'")
          isUniquelyDeclared = false
          break
        }
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

    private func unsureUniquelyDeclared(_ node: NamedDecl) -> Bool {
      for sibling in currentDeclContext.decls {
        if let decl = sibling as? NamedDecl,
          (decl !== node) && (decl.name != "") && (decl.name == node.name)
        {
          node.registerError(message: "invalid redeclaration of '\(node.name)'")
          return false
        }
      }
      return true
    }

    // MARK: Lexical scoping

    private func finalizeNamedDecl<Node>(_ node: Node) where Node: NamedDecl {
      currentDeclContext.decls.append(node)
      node.declContext = currentDeclContext
      node.traverse(with: self)
    }

    private func finalizeNamedContext<Node>(_ node: Node) where Node: NamedDecl & DeclContext {
      currentDeclContext.decls.append(node)
      node.declContext = currentDeclContext
      currentDeclContext = node
      node.traverse(with: self)
      currentDeclContext = node.declContext!
    }

  }

}
