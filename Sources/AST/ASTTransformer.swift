/// An AST transformor.
///
/// Conform to this protocol to implement an AST transformer. The default implementation traverses
/// the transformed node without transforming it with a depth-first preorder strategy, by calling the
/// `traverse` methods.
public protocol ASTTransformer {

  // MARK: - Declarations

  func transform(_ node: MainCodeDecl) -> ASTNode
  func transform(_ node: PropDecl) -> ASTNode
  func transform(_ node: FunDecl) -> ASTNode
  func transform(_ node: ParamDecl) -> ASTNode
  func transform(_ node: GenericParamDecl) -> ASTNode
  func transform(_ node: InterfaceDecl) -> ASTNode
  func transform(_ node: StructDecl) -> ASTNode
  func transform(_ node: UnionDecl) -> ASTNode
  func transform(_ node: UnionNestedDecl) -> ASTNode
  func transform(_ node: TypeExtDecl) -> ASTNode
  func transform(_ node: BuiltinTypeDecl) -> ASTNode

  // MARK: - Type signatures

  func transform(_ node: QualTypeSign) -> ASTNode
  func transform(_ node: IdentSign) -> ASTNode
  func transform(_ node: NestedIdentSign) -> ASTNode
  func transform(_ node: ImplicitNestedIdentSign) -> ASTNode
  func transform(_ node: FunSign) -> ASTNode
  func transform(_ node: ParamSign) -> ASTNode
  func transform(_ node: InvalidSign) -> ASTNode

  // MARK: - Statements

  func transform(_ node: BraceStmt) -> ASTNode
  func transform(_ node: IfStmt) -> ASTNode
  func transform(_ node: WhileStmt) -> ASTNode
  func transform(_ node: BindingStmt) -> ASTNode
  func transform(_ node: ReturnStmt) -> ASTNode
  func transform(_ node: InvalidStmt) -> ASTNode

  // MARK: - Expressions

  func transform(_ node: NullExpr) -> ASTNode
  func transform(_ node: LambdaExpr) -> ASTNode
  func transform(_ node: UnsafeCastExpr) -> ASTNode
  func transform(_ node: InfixExpr) -> ASTNode
  func transform(_ node: PrefixExpr) -> ASTNode
  func transform(_ node: CallExpr) -> ASTNode
  func transform(_ node: CallArgExpr) -> ASTNode
  func transform(_ node: IdentExpr) -> ASTNode
  func transform(_ node: SelectExpr) -> ASTNode
  func transform(_ node: ImplicitSelectExpr) -> ASTNode
  func transform(_ node: ArrayLitExpr) -> ASTNode
  func transform(_ node: SetLitExpr) -> ASTNode
  func transform(_ node: MapLitExpr) -> ASTNode
  func transform(_ node: MapLitElem) -> ASTNode
  func transform(_ node: BoolLitExpr) -> ASTNode
  func transform(_ node: IntLitExpr) -> ASTNode
  func transform(_ node: FloatLitExpr) -> ASTNode
  func transform(_ node: StrLitExpr) -> ASTNode
  func transform(_ node: ParenExpr) -> ASTNode
  func transform(_ node: InvalidExpr) -> ASTNode


  // MARK: - Attributes, modifiers and directives

  func transform(_ node: DeclAttr) -> ASTNode
  func transform(_ node: DeclModifier) -> ASTNode
  func transform(_ node: Directive) -> ASTNode

}
