import AST
import Utils

/// A module pass that finalizes the construction of a parsed AST.
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

      if isValidDeclaration(node) && (currentDeclContext !== node.module) {
        currentDeclContext.decls.append(node)
      }
      finalizeNamedDecl(node)
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

      // Make sure all parameters have a type signature.
      for param in node.params where param.sign == nil {
        param.registerError(message: Issue.missingParamSign())
      }

      if isValidDeclaration(node) && (currentDeclContext !== node.module) {
        currentDeclContext.decls.append(node)
      }
      finalizeNamedContext(node)
    }

    func visit(_ node: GenericParamDecl) {
      if isValidDeclaration(node) && (currentDeclContext !== node.module) {
        currentDeclContext.decls.append(node)
      }
      finalizeNamedDecl(node)
    }

    func visit(_ node: ParamDecl) {
      if isValidDeclaration(node) && (currentDeclContext !== node.module) {
        currentDeclContext.decls.append(node)
      }
      finalizeNamedDecl(node)
    }

    func visit(_ node: InterfaceDecl) {
      if isValidDeclaration(node) && (currentDeclContext !== node.module) {
        currentDeclContext.decls.append(node)
      }
      finalizeNamedContext(node)
    }

    func visit(_ node: StructDecl) {
      if isValidDeclaration(node) && (currentDeclContext !== node.module) {
        currentDeclContext.decls.append(node)
      }
      finalizeNamedContext(node)
    }

    func visit(_ node: UnionDecl) {
      if isValidDeclaration(node) && (currentDeclContext !== node.module) {
        currentDeclContext.decls.append(node)
      }
      finalizeNamedContext(node)
    }

    func visit(_ node: TypeExtDecl) {
      // Check that the extension is declared at top-level.
      if currentDeclContext !== node.module {
        node.registerError(message: Issue.nestedExtDecl(extDecl: node))
      }

      if currentDeclContext !== node.module {
        currentDeclContext.decls.append(node)
      }
      node.parent = currentDeclContext

      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

    func visit(_ node: BraceStmt) {
      node.parent = currentDeclContext
      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

    // MARK: Helpers

    private func isValidDeclaration(_ node: NamedDecl) -> Bool {
      // Skip nodes that do not have a valid name.
      guard node.name != ""
        else { return false }

      // Check for sibling declarations with the same name.
      for sibling in currentDeclContext.decls {
        if let decl = sibling as? NamedDecl,
          (decl !== node) && (decl.name == node.name)
            && !(decl.isOverloadable && node.isOverloadable)
        {
          node.registerError(message: Issue.invalidRedeclaration(name: node.name))
          return false
        }
      }

      // Check for declarations in function and declaration headers.
      let parent = currentDeclContext.parent
      if (parent is FunDecl) || (parent is NominalTypeDecl) {
        for sibling in parent!.decls {
          if let decl = sibling as? NamedDecl,
            (decl.name == node.name) && !(decl.isOverloadable && node.isOverloadable)
          {
            node.registerError(message: Issue.invalidRedeclaration(name: node.name))
            return false
          }
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
      node.declContext = currentDeclContext
      node.traverse(with: self)
    }

    private func finalizeNamedContext<Node>(_ node: Node) where Node: NamedDecl & DeclContext {
      node.declContext = currentDeclContext
      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

  }

}
