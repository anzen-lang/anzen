public protocol ModuleLoader {

  func load(_ moduleID: ModuleIdentifier, in context: ASTContext) -> ModuleDecl?

}
