public protocol ASTTransformer {

  func transform(_ node: ModuleDecl) -> Node
  func transform(_ node: Block) -> Node

  // MARK: Declarations

  func transform(_ node: PropDecl) -> Node
  func transform(_ node: FunDecl) -> Node
  func transform(_ node: ParamDecl) -> Node
  func transform(_ node: StructDecl) -> Node
  func transform(_ node: UnionNestedMemberDecl) -> Node
  func transform(_ node: UnionDecl) -> Node
  func transform(_ node: InterfaceDecl) -> Node

  // MARK: Type signatures

  func transform(_ node: QualTypeSign) -> Node
  func transform(_ node: TypeIdent) -> Node
  func transform(_ node: FunSign) -> Node
  func transform(_ node: ParamSign) -> Node

  // MARK: Statements

  func transform(_ node: Directive) -> Node
  func transform(_ node: WhileLoop) -> Node
  func transform(_ node: BindingStmt) -> Node
  func transform(_ node: ReturnStmt) -> Node

  // MARK: Expressions

  func transform(_ node: NullRef) -> Node
  func transform(_ node: IfExpr) -> Node
  func transform(_ node: LambdaExpr) -> Node
  func transform(_ node: CastExpr) -> Node
  func transform(_ node: BinExpr) -> Node
  func transform(_ node: UnExpr) -> Node
  func transform(_ node: CallExpr) -> Node
  func transform(_ node: CallArg) -> Node
  func transform(_ node: SubscriptExpr) -> Node
  func transform(_ node: SelectExpr) -> Node
  func transform(_ node: Ident) -> Node
  func transform(_ node: ArrayLiteral) -> Node
  func transform(_ node: SetLiteral) -> Node
  func transform(_ node: MapLiteral) -> Node
  func transform(_ node: Literal<Bool>) -> Node
  func transform(_ node: Literal<Int>) -> Node
  func transform(_ node: Literal<Double>) -> Node
  func transform(_ node: Literal<String>) -> Node

}
