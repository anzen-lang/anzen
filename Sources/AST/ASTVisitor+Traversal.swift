public extension ASTVisitor {

  // swiftlint:disable cyclomatic_complexity
  func visit(_ node: Node) {
    switch node {
    case let n as ModuleDecl:             visit(n)
    case let n as Block:                  visit(n)
    case let n as PropDecl:               visit(n)
    case let n as FunDecl:                visit(n)
    case let n as ParamDecl:              visit(n)
    case let n as StructDecl:             visit(n)
    case let n as UnionNestedMemberDecl:  visit(n)
    case let n as UnionDecl:              visit(n)
    case let n as InterfaceDecl:          visit(n)
    case let n as QualTypeSign:           visit(n)
    case let n as TypeIdent:              visit(n)
    case let n as FunSign:                visit(n)
    case let n as ParamSign:              visit(n)
    case let n as Directive:              visit(n)
    case let n as WhileLoop:              visit(n)
    case let n as BindingStmt:            visit(n)
    case let n as ReturnStmt:             visit(n)
    case let n as NullRef:                visit(n)
    case let n as IfExpr:                 visit(n)
    case let n as LambdaExpr:             visit(n)
    case let n as CastExpr:               visit(n)
    case let n as BinExpr:                visit(n)
    case let n as UnExpr:                 visit(n)
    case let n as CallExpr:               visit(n)
    case let n as CallArg:                visit(n)
    case let n as SubscriptExpr:          visit(n)
    case let n as SelectExpr:             visit(n)
    case let n as Ident:                  visit(n)
    case let n as ArrayLiteral:           visit(n)
    case let n as SetLiteral:             visit(n)
    case let n as MapLiteral:             visit(n)
    case let n as Literal<Bool>:          visit(n)
    case let n as Literal<Int>:           visit(n)
    case let n as Literal<Double>:        visit(n)
    case let n as Literal<String>:        visit(n)
    default:
      assertionFailure("unexpected node during generic visit")
    }
  }
  // swiftlint:enable cyclomatic_complexity

  func visit(_ nodes: [Node]) {
    for node in nodes {
      visit(node)
    }
  }

  func visit(_ node: ModuleDecl) {
    traverse(node)
  }

  func traverse(_ node: ModuleDecl) {
    visit(node.statements)
  }

  func visit(_ node: Block) {
    traverse(node)
  }

  func traverse(_ node: Block) {
    visit(node.statements)
  }

  // MARK: Declarations

  func visit(_ node: PropDecl) {
    traverse(node)
  }

  func traverse(_ node: PropDecl) {
    if let typeAnnotation = node.typeAnnotation {
      visit(typeAnnotation)
    }
    if let (_, value) = node.initialBinding {
      visit(value)
    }
  }

  func visit(_ node: FunDecl) {
    traverse(node)
  }

  func traverse(_ node: FunDecl) {
    visit(node.parameters)
    if let codomain = node.codomain {
      visit(codomain)
    }
    if let body = node.body {
      visit(body)
    }
  }

  func visit(_ node: ParamDecl) {
    traverse(node)
  }

  func traverse(_ node: ParamDecl) {
    if let annotation = node.typeAnnotation {
      visit(annotation)
    }
  }

  func visit(_ node: StructDecl) {
    traverse(node)
  }

  func traverse(_ node: StructDecl) {
    visit(node.body)
  }

  func visit(_ node: UnionNestedMemberDecl) {
    traverse(node)
  }

  func traverse(_ node: UnionNestedMemberDecl) {
    visit(node.nominalTypeDecl)
  }

  func visit(_ node: UnionDecl) {
    traverse(node)
  }

  func traverse(_ node: UnionDecl) {
    visit(node.body)
  }

  func visit(_ node: InterfaceDecl) {
    traverse(node)
  }

  func traverse(_ node: InterfaceDecl) {
    visit(node.body)
  }

  // MARK: Type signatures

  func visit(_ node: QualTypeSign) {
    traverse(node)
  }

  func traverse(_ node: QualTypeSign) {
    if let signature = node.signature {
      visit(signature)
    }
  }

  func visit(_ node: TypeIdent) {
    traverse(node)
  }

  func traverse(_ node: TypeIdent) {
    visit(Array(node.specializations.values))
  }

  func visit(_ node: FunSign) {
    traverse(node)
  }

  func traverse(_ node: FunSign) {
    visit(node.parameters)
    visit(node.codomain)
  }

  func visit(_ node: ParamSign) {
    traverse(node)
  }

  func traverse(_ node: ParamSign) {
    visit(node.typeAnnotation)
  }

  // MARK: Statements

  func visit(_ node: Directive) {
  }

  func visit(_ node: WhileLoop) {
    traverse(node)
  }

  func traverse(_ node: WhileLoop) {
    visit(node.condition)
    visit(node.body)
  }

  func visit(_ node: BindingStmt) {
    traverse(node)
  }

  func traverse(_ node: BindingStmt) {
    visit(node.lvalue)
    visit(node.rvalue)
  }

  func visit(_ node: ReturnStmt) {
    traverse(node)
  }

  func traverse(_ node: ReturnStmt) {
    if let (_, value) = node.binding {
      visit(value)
    }
  }

  // MARK: Expressions

  func visit(_ node: NullRef) {
  }

  func visit(_ node: IfExpr) {
    traverse(node)
  }

  func traverse(_ node: IfExpr) {
    visit(node.condition)
    visit(node.thenBlock)
    if let elseBlock = node.elseBlock {
      visit(elseBlock)
    }
  }

  func visit(_ node: LambdaExpr) {
    traverse(node)
  }

  func traverse(_ node: LambdaExpr) {
    visit(node.parameters)
    if let codomain = node.codomain {
      visit(codomain)
    }
    visit(node.body)
  }

  func visit(_ node: CastExpr) {
    traverse(node)
  }

  func traverse(_ node: CastExpr) {
    visit(node.operand)
    visit(node.castType)
  }

  func visit(_ node: BinExpr) {
    traverse(node)
  }

  func traverse(_ node: BinExpr) {
    visit(node.left)
    visit(node.right)
  }

  func visit(_ node: UnExpr) {
    traverse(node)
  }

  func traverse(_ node: UnExpr) {
    visit(node.operand)
  }

  func visit(_ node: CallExpr) {
    traverse(node)
  }

  func traverse(_ node: CallExpr) {
    visit(node.callee)
    visit(node.arguments)
  }

  func visit(_ node: CallArg) {
    traverse(node)
  }

  func traverse(_ node: CallArg) {
    visit(node.value)
  }

  func visit(_ node: SubscriptExpr) {
    traverse(node)
  }

  func traverse(_ node: SubscriptExpr) {
    visit(node.callee)
    visit(node.arguments)
  }

  func visit(_ node: SelectExpr) {
    traverse(node)
  }

  func traverse(_ node: SelectExpr) {
    if let owner = node.owner {
      visit(owner)
    }
    visit(node.ownee)
  }

  func visit(_ node: Ident) {
    traverse(node)
  }

  func traverse(_ node: Ident) {
    visit(Array(node.specializations.values))
  }

  func visit(_ node: ArrayLiteral) {
    traverse(node)
  }

  func traverse(_ node: ArrayLiteral) {
    visit(node.elements)
  }

  func visit(_ node: SetLiteral) {
    traverse(node)
  }

  func traverse(_ node: SetLiteral) {
    visit(node.elements)
  }

  func visit(_ node: MapLiteral) {
    traverse(node)
  }

  func traverse(_ node: MapLiteral) {
    visit(Array(node.elements.values))
  }

  func visit(_ node: Literal<Bool>) {
  }

  func visit(_ node: Literal<Int>) {
  }

  func visit(_ node: Literal<Double>) {
  }

  func visit(_ node: Literal<String>) {
  }

}
