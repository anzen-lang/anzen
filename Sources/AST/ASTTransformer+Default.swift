public extension ASTTransformer {

  // swiftlint:disable cyclomatic_complexity
  func transform(_ node: Node) -> Node {
    switch node {
    case let n as ModuleDecl:             return transform(n)
    case let n as Block:                  return transform(n)
    case let n as PropDecl:               return transform(n)
    case let n as FunDecl:                return transform(n)
    case let n as ParamDecl:              return transform(n)
    case let n as StructDecl:             return transform(n)
    case let n as UnionNestedMemberDecl:  return transform(n)
    case let n as UnionDecl:              return transform(n)
    case let n as InterfaceDecl:          return transform(n)
    case let n as QualTypeSign:           return transform(n)
    case let n as TypeIdent:              return transform(n)
    case let n as FunSign:                return transform(n)
    case let n as ParamSign:              return transform(n)
    case let n as Directive:              return transform(n)
    case let n as WhileLoop:              return transform(n)
    case let n as BindingStmt:            return transform(n)
    case let n as ReturnStmt:             return transform(n)
    case let n as NullRef:                return transform(n)
    case let n as IfExpr:                 return transform(n)
    case let n as LambdaExpr:             return transform(n)
    case let n as CastExpr:               return transform(n)
    case let n as BinExpr:                return transform(n)
    case let n as UnExpr:                 return transform(n)
    case let n as CallExpr:               return transform(n)
    case let n as CallArg:                return transform(n)
    case let n as SubscriptExpr:          return transform(n)
    case let n as SelectExpr:             return transform(n)
    case let n as Ident:                  return transform(n)
    case let n as ArrayLiteral:           return transform(n)
    case let n as SetLiteral:             return transform(n)
    case let n as MapLiteral:             return transform(n)
    case let n as Literal<Bool>:          return transform(n)
    case let n as Literal<Int>:           return transform(n)
    case let n as Literal<Double>:        return transform(n)
    case let n as Literal<String>:        return transform(n)
    default:
      fatalError("unexpected node during generic transform")
    }
  }
  // swiftlint:enable cyclomatic_complexity

  func transform(_ node: ModuleDecl) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: ModuleDecl) -> ModuleDecl {
    node.statements = node.statements.map(transform)
    return node
  }

  func transform(_ node: Block) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: Block) -> Block {
    node.statements = node.statements.map(transform)
    return node
  }

  // MARK: Declarations

  func transform(_ node: PropDecl) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: PropDecl) -> PropDecl {
    node.typeAnnotation = node.typeAnnotation.map { transform($0) as! QualTypeSign }
    if let (op, value) = node.initialBinding {
      node.initialBinding = (op: op, value: transform(value) as! Expr)
    }
    return node
  }

  func transform(_ node: FunDecl) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: FunDecl) -> FunDecl {
    node.directives = node.directives.map(transform) as! [Directive]
    node.parameters = node.parameters.map(transform) as! [ParamDecl]
    node.codomain = node.codomain.map(transform)
    node.body = node.body.map { transform($0) as! Block }
    return node
  }

  func transform(_ node: ParamDecl) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: ParamDecl) -> ParamDecl {
    node.typeAnnotation = node.typeAnnotation.map { transform($0) as! QualTypeSign }
    node.defaultValue = node.defaultValue.map { transform($0) as! Expr }
    return node
  }

  func transform(_ node: StructDecl) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: StructDecl) -> StructDecl {
    node.body = transform(node.body) as! Block
    return node
  }

  func transform(_ node: UnionNestedMemberDecl) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: UnionNestedMemberDecl) -> UnionNestedMemberDecl {
    node.nominalTypeDecl = transform(node.nominalTypeDecl) as! NominalTypeDecl
    return node
  }

  func transform(_ node: UnionDecl) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: UnionDecl) -> UnionDecl {
    node.body = transform(node.body) as! Block
    return node
  }

  func transform(_ node: InterfaceDecl) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: InterfaceDecl) -> InterfaceDecl {
    node.body = transform(node.body) as! Block
    return node
  }

  // MARK: Type signatures

  func transform(_ node: QualTypeSign) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: QualTypeSign) -> QualTypeSign {
    node.signature = node.signature.map(transform)
    return node
  }

  func transform(_ node: TypeIdent) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: TypeIdent) -> TypeIdent {
    node.specializations = Dictionary(
      uniqueKeysWithValues: node.specializations.map({
        ($0, transform($1) as! QualTypeSign)
      }))
    return node
  }

  func transform(_ node: FunSign) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: FunSign) -> FunSign {
    node.parameters = node.parameters.map(transform) as! [ParamSign]
    node.codomain = transform(node.codomain)
    return node
  }

  func transform(_ node: ParamSign) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: ParamSign) -> ParamSign {
    node.typeAnnotation = transform(node.typeAnnotation)
    return node
  }

  // MARK: Statements

  func transform(_ node: Directive) -> Node {
    return node
  }

  func transform(_ node: WhileLoop) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: WhileLoop) -> WhileLoop {
    node.condition = transform(node.condition) as! Expr
    node.body = transform(node.body) as! Block
    return node
  }

  func transform(_ node: BindingStmt) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: BindingStmt) -> BindingStmt {
    node.lvalue = transform(node.lvalue) as! Expr
    node.rvalue = transform(node.rvalue) as! Expr
    return node
  }

  func transform(_ node: ReturnStmt) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: ReturnStmt) -> ReturnStmt {
    if let (op, value) = node.binding {
      let newValue = transform(value)
      node.binding = (op, newValue as! Expr)
    }
    return node
  }

  // MARK: Expressions

  func transform(_ node: NullRef) -> Node {
    return node
  }

  func transform(_ node: IfExpr) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: IfExpr) -> IfExpr {
    node.condition = transform(node.condition) as! Expr
    node.thenBlock = transform(node.thenBlock)
    node.elseBlock = node.elseBlock.map(transform)
    return node
  }

  func transform(_ node: LambdaExpr) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: LambdaExpr) -> LambdaExpr {
    node.parameters = node.parameters.map(transform) as! [ParamDecl]
    node.codomain = node.codomain.map(transform)
    node.body = transform(node.body) as! Block
    return node
  }

  func transform(_ node: CastExpr) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: CastExpr) -> CastExpr {
    node.operand = transform(node.operand) as! Expr
    node.castType = transform(node.castType) as! TypeSign
    return node
  }

  func transform(_ node: BinExpr) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: BinExpr) -> BinExpr {
    node.left = transform(node.left) as! Expr
    node.right = transform(node.right) as! Expr
    return node
  }

  func transform(_ node: UnExpr) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: UnExpr) -> UnExpr {
    node.operand = transform(node.operand) as! Expr
    return node
  }

  func transform(_ node: CallExpr) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: CallExpr) -> CallExpr {
    node.callee = transform(node.callee) as! Expr
    node.arguments = node.arguments.map(transform) as! [CallArg]
    return node
  }

  func transform(_ node: CallArg) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: CallArg) -> CallArg {
    node.value = transform(node.value) as! Expr
    return node
  }

  func transform(_ node: SubscriptExpr) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: SubscriptExpr) -> SubscriptExpr {
    node.callee = transform(node.callee) as! Expr
    node.arguments = node.arguments.map(transform) as! [CallArg]
    return node
  }

  func transform(_ node: SelectExpr) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: SelectExpr) -> SelectExpr {
    node.owner = node.owner.map { transform($0) as! Expr }
    node.ownee = transform(node.ownee) as! Ident
    return node
  }

  func transform(_ node: Ident) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: Ident) -> Ident {
    node.specializations = Dictionary(
      uniqueKeysWithValues: node.specializations.map({
        ($0, transform($1) as! QualTypeSign)
      }))
    return node
  }

  func transform(_ node: ArrayLiteral) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: ArrayLiteral) -> ArrayLiteral {
    node.elements = node.elements.map(transform) as! [Expr]
    return node
  }

  func transform(_ node: SetLiteral) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: SetLiteral) -> SetLiteral {
    node.elements = node.elements.map(transform) as! [Expr]
    return node
  }

  func transform(_ node: MapLiteral) -> Node {
    return defaultTransform(node)
  }

  func defaultTransform(_ node: MapLiteral) -> MapLiteral {
    node.elements = Dictionary(
      uniqueKeysWithValues: node.elements.map({ ($0, transform($1) as! Expr) }))
    return node
  }

  func transform(_ node: Literal<Bool>) -> Node {
    return node
  }

  func transform(_ node: Literal<Int>) -> Node {
    return node
  }

  func transform(_ node: Literal<Double>) -> Node {
    return node
  }

  func transform(_ node: Literal<String>) -> Node {
    return node
  }

}
