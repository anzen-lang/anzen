public protocol ASTTransformer {

  func transform(_ node: ModuleDecl)      throws -> Node
  func transform(_ node: Block)           throws -> Node

  // MARK: Declarations

  func transform(_ node: PropDecl)        throws -> Node
  func transform(_ node: FunDecl)         throws -> Node
  func transform(_ node: ParamDecl)       throws -> Node
  func transform(_ node: StructDecl)      throws -> Node
  func transform(_ node: InterfaceDecl)   throws -> Node

  // MARK: Type signatures

  func transform(_ node: QualTypeSign)    throws -> Node
  func transform(_ node: TypeIdent)       throws -> Node
  func transform(_ node: FunSign)         throws -> Node
  func transform(_ node: ParamSign)       throws -> Node

  // MARK: Statements

  func transform(_ node: Directive)       throws -> Node
  func transform(_ node: WhileLoop)       throws -> Node
  func transform(_ node: BindingStmt)     throws -> Node
  func transform(_ node: ReturnStmt)      throws -> Node

  // MARK: Expressions

  func transform(_ node: NullRef)         throws -> Node
  func transform(_ node: IfExpr)          throws -> Node
  func transform(_ node: LambdaExpr)      throws -> Node
  func transform(_ node: CastExpr)        throws -> Node
  func transform(_ node: BinExpr)         throws -> Node
  func transform(_ node: UnExpr)          throws -> Node
  func transform(_ node: CallExpr)        throws -> Node
  func transform(_ node: CallArg)         throws -> Node
  func transform(_ node: SubscriptExpr)   throws -> Node
  func transform(_ node: SelectExpr)      throws -> Node
  func transform(_ node: Ident)           throws -> Node
  func transform(_ node: ArrayLiteral)    throws -> Node
  func transform(_ node: SetLiteral)      throws -> Node
  func transform(_ node: MapLiteral)      throws -> Node
  func transform(_ node: Literal<Bool>)   throws -> Node
  func transform(_ node: Literal<Int>)    throws -> Node
  func transform(_ node: Literal<Double>) throws -> Node
  func transform(_ node: Literal<String>) throws -> Node

}
