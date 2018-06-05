import AST

/// Base protocol for all static analysis passes.
public protocol SAPass {

  init(context: ASTContext)

  mutating func visit(_ node: ModuleDecl) throws

  /// The AST context.
  var context: ASTContext { get }

}
