import AST

/// A module pass that attaches to each function declaration the identifiers it captures.
///
/// This pass must take place after type checking, as it requires all identifiers to have been
/// properly associated with the declaration to which they refer.
///
/// Strictly speaking, an identifier is captured if it's declared in a scope that encloses the
/// function in which it's used. However, some identifiers must be excluded from this definition.
/// Identifiers referring to types and top-level declarations do not constitute captures, as those
/// are not context-sensitive. Moreover, identifiers referring to properties within methods do not
/// constitute captures either, as those actually represent an implicit select expression of the
/// form `self.identifier`.
public struct CaptureAnalysisPass {

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
    let analyzer = CaptureAnalyzer(context: context)
    for decl in module.decls {
      decl.accept(visitor: analyzer)
    }
  }

  // MARK: Internal visitor

  private final class CaptureAnalyzer: ASTVisitor {

    /// The compiler context.
    let context: CompilerContext

    /// An array of all visited functions.
    ///
    /// This list is used in a second step to remove from capture lists the function declarations
    /// that do not capture any symbol. Those can be hoisted, as the declaration context in which
    /// they are defined is not required to emit their code.
    var visitedFunDecls: [FunDecl] = []

    /// The inner-most function being visited.
    private var currentFunDecl: FunDecl?

    init(context: CompilerContext) {
      self.context = context
    }

    func visit(_ node: FunDecl) {
      let previousFunDecl = currentFunDecl
      currentFunDecl = node
      node.traverse(with: self)

      // Add to the capture list of the previous function the identifiers captured by the current
      // one, whose declarations are not enclosed by the former's declaration context.
      if let funDecl = previousFunDecl {
        funDecl.capturedDecls.append(contentsOf: node.capturedDecls.filter { decl in
          decl.declContext!.isEnclosing(funDecl)
        })
      }

      currentFunDecl = previousFunDecl
      visitedFunDecls.append(node)
    }

    func visit(_ node: IdentExpr) {
      // Discard identifiers that could not be associated with any declaration.
      guard let referredDecl = node.referredDecls.first
        else { return }

      // There's nothing to do if the identifier isn't used in the context of a function.
      guard let currentFunDecl = self.currentFunDecl
        else { return }

      // Type declarations are not flow-sensitive values, so they shouldn't be included.
      guard !(referredDecl is TypeDecl)
        else { return }

      // Top-level declarations are not flow-sensitive, so they shouldn't be included.
      guard referredDecl.declContext !== node.module
        else { return }

      if !referredDecl.declContext!.isEnclosed(in: currentFunDecl) {
        if currentFunDecl.kind == .regular {
          // Identifiers declared outside of a regular function are considered captured.
          // WARNING: This is a linear search.
          if !currentFunDecl.capturedDecls.contains(where: { $0 === referredDecl }) {
            currentFunDecl.capturedDecls.append(referredDecl)
          }

          return
        }

        // If the current function is a method, first determine whether the identifier refers to a
        // property or method, declared in the same type.
        let methTypeDecl = currentFunDecl.resolveEncolsingTypeDecl(inCompilerContext: context)
        let propTypeDecl = referredDecl.resolveEncolsingTypeDecl(inCompilerContext: context)

        // If the method and the property are siblings in the same type context, the identifier is
        // not captured, but rather refers to an implicit select expression with `self` as owner.
        guard methTypeDecl !== propTypeDecl
          else { return }

        // The identifier is captured, unless we can later determine it's flow-insenstivie.
        node.registerError(message: Issue.illegalCaptureInMethod(ident: node))
      }
    }

    func visit(_ node: SelectExpr) {
      node.owner.accept(visitor: self)
    }

    func visit(_ node: ImplicitSelectExpr) {
    }

  }

}
