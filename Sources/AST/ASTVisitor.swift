public protocol ASTVisitor {

  func visit(_ node: ModuleDecl)            throws
  func visit(_ node: Block)                 throws

  // MARK: Declarations

  func visit(_ node: PropDecl)              throws
  func visit(_ node: FunDecl)               throws
  func visit(_ node: ParamDecl)             throws
  func visit(_ node: StructDecl)            throws
  func visit(_ node: UnionNestedMemberDecl) throws
  func visit(_ node: UnionDecl)             throws
  func visit(_ node: InterfaceDecl)         throws

  // MARK: Type signatures

  func visit(_ node: QualTypeSign)          throws
  func visit(_ node: TypeIdent)             throws
  func visit(_ node: FunSign)               throws
  func visit(_ node: ParamSign)             throws

  // MARK: Statements

  func visit(_ node: Directive)             throws
  func visit(_ node: WhileLoop)             throws
  func visit(_ node: BindingStmt)           throws
  func visit(_ node: ReturnStmt)            throws

  // MARK: Expressions

  func visit(_ node: NullRef)               throws
  func visit(_ node: IfExpr)                throws
  func visit(_ node: LambdaExpr)            throws
  func visit(_ node: CastExpr)              throws
  func visit(_ node: BinExpr)               throws
  func visit(_ node: UnExpr)                throws
  func visit(_ node: CallExpr)              throws
  func visit(_ node: CallArg)               throws
  func visit(_ node: SubscriptExpr)         throws
  func visit(_ node: SelectExpr)            throws
  func visit(_ node: Ident)                 throws
  func visit(_ node: ArrayLiteral)          throws
  func visit(_ node: SetLiteral)            throws
  func visit(_ node: MapLiteral)            throws
  func visit(_ node: Literal<Bool>)         throws
  func visit(_ node: Literal<Int>)          throws
  func visit(_ node: Literal<Double>)       throws
  func visit(_ node: Literal<String>)       throws

}
