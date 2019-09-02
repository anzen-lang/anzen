import AST

/// A module pass that attaches to each function declaration the identifiers it captures.
///
/// This pass must take place after type checking, as it requires all identifiers to have been
/// properly associated with the declaration to which they refer.
public struct CaptureAnalysisPass {

  /// The module being processed.
  public let module: Module

  public init(module: Module) {
    assert(module.state == .parsed, "module has not been parsed yet")
    self.module = module
  }

  public func process() {
    let analyzer = CaptureAnalyzer()
    for decl in module.decls where decl is FunDecl {
      decl.accept(visitor: analyzer)
    }

    for funDecl in analyzer.visitedFunDecls {
      // Remove functions declarations that do not capture any symbol.
      funDecl.capturedDecls.removeAll { namedDecl in
        (namedDecl as? FunDecl)?.capturedDecls.isEmpty ?? false
      }

      if !funDecl.capturedDecls.isEmpty {
        if funDecl.declContext === module {
          // Top-level declarations re not allowed to capture any symbol.
          for decl in funDecl.capturedDecls {
            funDecl.registerError(message: Issue.illegalTopLevelCapture(decl: decl))
          }
        }
      }
    }
  }

  // MARK: Internal visitor

  private final class CaptureAnalyzer: ASTVisitor {

    /// The inner-most function being visited.
    private var currentFunDecl: FunDecl?

    /// An array of all visited functions.
    ///
    /// This list is used in a second step to remove from capture lists the function declarations
    /// that do not capture any symbol. Those can be hoisted, as the declaration context in which
    /// they are defined is not required to emit their code.
    var visitedFunDecls: [FunDecl] = []

    func visit(_ node: FunDecl) {
      let previousFunDecl = currentFunDecl
      currentFunDecl = node
      node.traverse(with: self)

      // Add to the capture list of the previous function the declarations captured by the current
      // one, which are not enclosed by the former's declaration context.
      if let funDecl = previousFunDecl {
        funDecl.capturedDecls.append(contentsOf: node.capturedDecls.filter { capturedDecl in
          capturedDecl.declContext!.isEnclosing(funDecl)
        })
      }

      currentFunDecl = previousFunDecl
      visitedFunDecls.append(node)
    }

    func visit(_ node: IdentExpr) {
      // There's nothing to do if the identifier isn't used in a function.
      guard currentFunDecl != nil
        else { return }

      // There's nothing to do if the referred decl corresponds to a type declaration, as those are
      // not flow-sensitive values.
      guard let referredDecl = node.referredDecls.first
        else { return }
      guard !(referredDecl is TypeDecl)
        else { return }


      if referredDecl.declContext!.isEnclosing(currentFunDecl!) {
        // In a firt step, we add any non-type identifier referring to a declaration whose context
        // encloses the current function in the latter's capture set.
        currentFunDecl!.capturedDecls.append(referredDecl)
      }
    }

    func visit(_ node: SelectExpr) {
      node.owner.accept(visitor: self)
    }

    func visit(_ node: ImplicitSelectExpr) {
    }

  }

}
