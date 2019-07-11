public extension ASTTransformer {

  // swiftlint:disable cyclomatic_complexity
  func transform(_ node: Node) throws -> Node {
    switch node {
    case let n as ModuleDecl:      return try transform(n)
    case let n as Block:           return try transform(n)
    case let n as PropDecl:        return try transform(n)
    case let n as FunDecl:         return try transform(n)
    case let n as ParamDecl:       return try transform(n)
    case let n as StructDecl:      return try transform(n)
    case let n as InterfaceDecl:   return try transform(n)
    case let n as QualTypeSign:    return try transform(n)
    case let n as TypeIdent:       return try transform(n)
    case let n as FunSign:         return try transform(n)
    case let n as ParamSign:       return try transform(n)
    case let n as WhileLoop:       return try transform(n)
    case let n as BindingStmt:     return try transform(n)
    case let n as ReturnStmt:      return try transform(n)
    case let n as IfExpr:          return try transform(n)
    case let n as LambdaExpr:      return try transform(n)
    case let n as CastExpr:        return try transform(n)
    case let n as BinExpr:         return try transform(n)
    case let n as UnExpr:          return try transform(n)
    case let n as CallExpr:        return try transform(n)
    case let n as CallArg:         return try transform(n)
    case let n as SubscriptExpr:   return try transform(n)
    case let n as SelectExpr:      return try transform(n)
    case let n as Ident:           return try transform(n)
    case let n as ArrayLiteral:    return try transform(n)
    case let n as SetLiteral:      return try transform(n)
    case let n as MapLiteral:      return try transform(n)
    case let n as Literal<Bool>:   return try transform(n)
    case let n as Literal<Int>:    return try transform(n)
    case let n as Literal<Double>: return try transform(n)
    case let n as Literal<String>: return try transform(n)
    case let n as UnparsableInput: return try transform(n)
    default:
      fatalError("unexpected node during generic transform")
    }
  }
  // swiftlint:enable cyclomatic_complexity

  func transform(_ node: ModuleDecl) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: ModuleDecl) throws -> ModuleDecl {
    node.statements = try node.statements.map(transform)
    return node
  }

  func transform(_ node: Block) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: Block) throws -> Block {
    node.statements = try node.statements.map(transform)
    return node
  }

  // MARK: Declarations

  func transform(_ node: PropDecl) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: PropDecl) throws -> PropDecl {
    node.typeAnnotation = try node.typeAnnotation.map { try transform($0) as! QualTypeSign }
    if let (op, value) = node.initialBinding {
      node.initialBinding = (op: op, value: try transform(value) as! Expr)
    }
    return node
  }

  func transform(_ node: FunDecl) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: FunDecl) throws -> FunDecl {
    node.parameters = try node.parameters.map(transform) as! [ParamDecl]
    node.codomain = try node.codomain.map(transform)
    node.body = try node.body.map { try transform($0) as! Block }
    return node
  }

  func transform(_ node: ParamDecl) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: ParamDecl) throws -> ParamDecl {
    node.typeAnnotation = try node.typeAnnotation.map { try transform($0) as! QualTypeSign }
    node.defaultValue = try node.defaultValue.map { try transform($0) as! Expr }
    return node
  }

  func transform(_ node: StructDecl) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: StructDecl) throws -> StructDecl {
    node.body = try transform(node.body) as! Block
    return node
  }

  func transform(_ node: InterfaceDecl) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: InterfaceDecl) throws -> InterfaceDecl {
    node.body = try transform(node.body) as! Block
    return node
  }

  // MARK: Type signatures

  func transform(_ node: QualTypeSign) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: QualTypeSign) throws -> QualTypeSign {
    node.signature = try node.signature.map(transform)
    return node
  }

  func transform(_ node: TypeIdent) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: TypeIdent) throws -> TypeIdent {
    node.specializations = try Dictionary(
      uniqueKeysWithValues: node.specializations.map({ try ($0, transform($1)) }))
    return node
  }

  func transform(_ node: FunSign) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: FunSign) throws -> FunSign {
    node.parameters = try node.parameters.map(transform) as! [ParamSign]
    node.codomain = try transform(node.codomain)
    return node
  }

  func transform(_ node: ParamSign) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: ParamSign) throws -> ParamSign {
    node.typeAnnotation = try transform(node.typeAnnotation)
    return node
  }

  // MARK: Statements

  func transform(_ node: WhileLoop) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: WhileLoop) throws -> WhileLoop {
    node.condition = try transform(node.condition) as! Expr
    node.body = try transform(node.body) as! Block
    return node
  }

  func transform(_ node: BindingStmt) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: BindingStmt) throws -> BindingStmt {
    node.lvalue = try transform(node.lvalue) as! Expr
    node.rvalue = try transform(node.rvalue) as! Expr
    return node
  }

  func transform(_ node: ReturnStmt) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: ReturnStmt) throws -> ReturnStmt {
    node.value = try node.value.map { try transform($0) as! Expr }
    return node
  }

  // MARK: Expressions

  func transform(_ node: IfExpr) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: IfExpr) throws -> IfExpr {
    node.condition = try transform(node.condition) as! Expr
    node.thenBlock = try transform(node.thenBlock)
    node.elseBlock = try node.elseBlock.map(transform)
    return node
  }

  func transform(_ node: LambdaExpr) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: LambdaExpr) throws -> LambdaExpr {
    node.parameters = try node.parameters.map(transform) as! [ParamDecl]
    node.codomain = try node.codomain.map(transform)
    node.body = try transform(node.body) as! Block
    return node
  }

  func transform(_ node: CastExpr) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: CastExpr) throws -> CastExpr {
    node.operand = try transform(node.operand) as! Expr
    node.castType = try transform(node.castType) as! TypeSign
    return node
  }

  func transform(_ node: BinExpr) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: BinExpr) throws -> BinExpr {
    node.left = try transform(node.left) as! Expr
    node.right = try transform(node.right) as! Expr
    return node
  }

  func transform(_ node: UnExpr) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: UnExpr) throws -> UnExpr {
    node.operand = try transform(node.operand) as! Expr
    return node
  }

  func transform(_ node: CallExpr) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: CallExpr) throws -> CallExpr {
    node.callee = try transform(node.callee) as! Expr
    node.arguments = try node.arguments.map(transform) as! [CallArg]
    return node
  }

  func transform(_ node: CallArg) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: CallArg) throws -> CallArg {
    node.value = try transform(node.value) as! Expr
    return node
  }

  func transform(_ node: SubscriptExpr) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: SubscriptExpr) throws -> SubscriptExpr {
    node.callee = try transform(node.callee) as! Expr
    node.arguments = try node.arguments.map(transform) as! [CallArg]
    return node
  }

  func transform(_ node: SelectExpr) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: SelectExpr) throws -> SelectExpr {
    node.owner = try node.owner.map { try transform($0) as! Expr }
    node.ownee = try transform(node.ownee) as! Ident
    return node
  }

  func transform(_ node: Ident) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: Ident) throws -> Ident {
    node.specializations = try Dictionary(
      uniqueKeysWithValues: node.specializations.map({ try ($0, transform($1)) }))
    return node
  }

  func transform(_ node: ArrayLiteral) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: ArrayLiteral) throws -> ArrayLiteral {
    node.elements = try node.elements.map(transform) as! [Expr]
    return node
  }

  func transform(_ node: SetLiteral) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: SetLiteral) throws -> SetLiteral {
    node.elements = try node.elements.map(transform) as! [Expr]
    return node
  }

  func transform(_ node: MapLiteral) throws -> Node {
    return try defaultTransform(node)
  }

  func defaultTransform(_ node: MapLiteral) throws -> MapLiteral {
    node.elements = try Dictionary(
      uniqueKeysWithValues: node.elements.map({ try ($0, transform($1) as! Expr) }))
    return node
  }

  func transform(_ node: Literal<Bool>) throws -> Node {
    return node
  }

  func transform(_ node: Literal<Int>) throws -> Node {
    return node
  }

  func transform(_ node: Literal<Double>) throws -> Node {
    return node
  }

  func transform(_ node: Literal<String>) throws -> Node {
    return node
  }

  // MARK: Input errors

  func transform(_ node: UnparsableInput) throws -> Node {
    return node
  }


}
