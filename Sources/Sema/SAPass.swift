import AST

/// Base protocol for all static analysis passes.
public protocol SAPass {

  init(context: ASTContext)

  mutating func visit(_ node: ModuleDecl) throws

  var context: ASTContext { get }

}
