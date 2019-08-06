/// An AST visitor.
///
/// Conform to this protocol to implement an AST visitor. The default implementation traverses the
/// visited node with a depth-first preorder strategy, by calling the `traverse` methods.
public protocol ASTVisitor {

  // MARK: - Declarations

  func visit(_ node: MainCodeDecl)
  func visit(_ node: PropDecl)
  func visit(_ node: FunDecl)
  func visit(_ node: ParamDecl)
  func visit(_ node: GenericParamDecl)
  func visit(_ node: InterfaceDecl)
  func visit(_ node: StructDecl)
  func visit(_ node: UnionDecl)
  func visit(_ node: UnionNestedDecl)

  // MARK: - Type signatures

  func visit(_ node: QualTypeSign)
  func visit(_ node: IdentSign)
  func visit(_ node: NestedIdentSign)
  func visit(_ node: ImplicitNestedIdentSign)
  func visit(_ node: FunSign)
  func visit(_ node: ParamSign)
  func visit(_ node: InvalidSign)

  // MARK: - Statements

  func visit(_ node: BraceStmt)
  func visit(_ node: IfStmt)
  func visit(_ node: WhileStmt)
  func visit(_ node: BindingStmt)
  func visit(_ node: ReturnStmt)
  func visit(_ node: InvalidStmt)

  // MARK: - Expressions

  func visit(_ node: NullExpr)
  func visit(_ node: LambdaExpr)
  func visit(_ node: UnsafeCastExpr)
  func visit(_ node: InfixExpr)
  func visit(_ node: PrefixExpr)
  func visit(_ node: CallExpr)
  func visit(_ node: CallArgExpr)
  func visit(_ node: IdentExpr)
  func visit(_ node: SelectExpr)
  func visit(_ node: ImplicitSelectExpr)
  func visit(_ node: ArrayLitExpr)
  func visit(_ node: SetLitExpr)
  func visit(_ node: MapLitExpr)
  func visit(_ node: MapLitElem)
  func visit(_ node: BoolLitExpr)
  func visit(_ node: IntLitExpr)
  func visit(_ node: FloatLitExpr)
  func visit(_ node: StrLitExpr)
  func visit(_ node: ParenExpr)
  func visit(_ node: InvalidExpr)

  // MARK: - Attributes, modifiers and directives

  func visit(_ node: DeclAttr)
  func visit(_ node: DeclModifier)
  func visit(_ node: Directive)

}

extension ASTVisitor {

  public func visit(_ node: MainCodeDecl) {
    node.traverse(with: self)
  }

  public func visit(_ node: PropDecl) {
    node.traverse(with: self)
  }

  public func visit(_ node: FunDecl) {
    node.traverse(with: self)
  }

  public func visit(_ node: ParamDecl) {
    node.traverse(with: self)
  }

  public func visit(_ node: GenericParamDecl) {
    node.traverse(with: self)
  }

  public func visit(_ node: InterfaceDecl) {
    node.traverse(with: self)
  }

  public func visit(_ node: StructDecl) {
    node.traverse(with: self)
  }

  public func visit(_ node: UnionDecl) {
    node.traverse(with: self)
  }

  public func visit(_ node: UnionNestedDecl) {
    node.traverse(with: self)
  }

  public func visit(_ node: QualTypeSign) {
    node.traverse(with: self)
  }

  public func visit(_ node: IdentSign) {
    node.traverse(with: self)
  }

  public func visit(_ node: NestedIdentSign) {
    node.traverse(with: self)
  }

  public func visit(_ node: ImplicitNestedIdentSign) {
    node.traverse(with: self)
  }

  public func visit(_ node: FunSign) {
    node.traverse(with: self)
  }

  public func visit(_ node: ParamSign) {
    node.traverse(with: self)
  }

  public func visit(_ node: InvalidSign) {
    node.traverse(with: self)
  }

  public func visit(_ node: BraceStmt) {
    node.traverse(with: self)
  }

  public func visit(_ node: IfStmt) {
    node.traverse(with: self)
  }

  public func visit(_ node: WhileStmt) {
    node.traverse(with: self)
  }

  public func visit(_ node: BindingStmt) {
    node.traverse(with: self)
  }

  public func visit(_ node: ReturnStmt) {
    node.traverse(with: self)
  }

  public func visit(_ node: InvalidStmt) {
    node.traverse(with: self)
  }

  public func visit(_ node: NullExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: LambdaExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: UnsafeCastExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: InfixExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: PrefixExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: CallExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: CallArgExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: IdentExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: SelectExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: ImplicitSelectExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: ArrayLitExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: SetLitExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: MapLitExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: MapLitElem) {
    node.traverse(with: self)
  }

  public func visit(_ node: BoolLitExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: IntLitExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: FloatLitExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: StrLitExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: ParenExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: InvalidExpr) {
    node.traverse(with: self)
  }

  public func visit(_ node: Directive) {
    node.traverse(with: self)
  }

  public func visit(_ node: DeclModifier) {
    node.traverse(with: self)
  }

  public func visit(_ node: DeclAttr) {
    node.traverse(with: self)
  }

}
