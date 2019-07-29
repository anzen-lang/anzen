public protocol ASTVisitor {

  func visit(_ node: ModuleDecl)
  func visit(_ node: Block)

  // MARK: Declarations

  func visit(_ node: PropDecl)
  func visit(_ node: FunDecl)
  func visit(_ node: ParamDecl)
  func visit(_ node: StructDecl)
  func visit(_ node: UnionNestedMemberDecl)
  func visit(_ node: UnionDecl)
  func visit(_ node: InterfaceDecl)

  // MARK: Type signatures

  func visit(_ node: QualTypeSign)
  func visit(_ node: TypeIdent)
  func visit(_ node: FunSign)
  func visit(_ node: ParamSign)

  // MARK: Statements

  func visit(_ node: Directive)
  func visit(_ node: WhileLoop)
  func visit(_ node: BindingStmt)
  func visit(_ node: ReturnStmt)

  // MARK: Expressions

  func visit(_ node: NullRef)
  func visit(_ node: IfExpr)
  func visit(_ node: LambdaExpr)
  func visit(_ node: CastExpr)
  func visit(_ node: BinExpr)
  func visit(_ node: UnExpr)
  func visit(_ node: CallExpr)
  func visit(_ node: CallArg)
  func visit(_ node: SubscriptExpr)
  func visit(_ node: SelectExpr)
  func visit(_ node: Ident)
  func visit(_ node: ArrayLiteral)
  func visit(_ node: SetLiteral)
  func visit(_ node: MapLiteral)
  func visit(_ node: Literal<Bool>)
  func visit(_ node: Literal<Int>)
  func visit(_ node: Literal<Double>)
  func visit(_ node: Literal<String>)

}
