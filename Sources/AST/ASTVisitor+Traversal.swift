public extension ASTVisitor {

  // swiftlint:disable cyclomatic_complexity
  func visit(_ node: Node) throws {
    switch node {
    case let n as ModuleDecl:             try visit(n)
    case let n as Block:                  try visit(n)
    case let n as PropDecl:               try visit(n)
    case let n as FunDecl:                try visit(n)
    case let n as ParamDecl:              try visit(n)
    case let n as StructDecl:             try visit(n)
    case let n as UnionNestedMemberDecl:  try visit(n)
    case let n as UnionDecl:              try visit(n)
    case let n as InterfaceDecl:          try visit(n)
    case let n as QualTypeSign:           try visit(n)
    case let n as TypeIdent:              try visit(n)
    case let n as FunSign:                try visit(n)
    case let n as ParamSign:              try visit(n)
    case let n as Directive:              try visit(n)
    case let n as WhileLoop:              try visit(n)
    case let n as BindingStmt:            try visit(n)
    case let n as ReturnStmt:             try visit(n)
    case let n as NullRef:                try visit(n)
    case let n as IfExpr:                 try visit(n)
    case let n as LambdaExpr:             try visit(n)
    case let n as CastExpr:               try visit(n)
    case let n as BinExpr:                try visit(n)
    case let n as UnExpr:                 try visit(n)
    case let n as CallExpr:               try visit(n)
    case let n as CallArg:                try visit(n)
    case let n as SubscriptExpr:          try visit(n)
    case let n as SelectExpr:             try visit(n)
    case let n as Ident:                  try visit(n)
    case let n as ArrayLiteral:           try visit(n)
    case let n as SetLiteral:             try visit(n)
    case let n as MapLiteral:             try visit(n)
    case let n as Literal<Bool>:          try visit(n)
    case let n as Literal<Int>:           try visit(n)
    case let n as Literal<Double>:        try visit(n)
    case let n as Literal<String>:        try visit(n)
    default:
      assertionFailure("unexpected node during generic visit")
    }
  }
  // swiftlint:enable cyclomatic_complexity

  func visit(_ nodes: [Node]) throws {
    for node in nodes {
      try visit(node)
    }
  }

  func visit(_ node: ModuleDecl) throws {
    try traverse(node)
  }

  func traverse(_ node: ModuleDecl) throws {
    try visit(node.statements)
  }

  func visit(_ node: Block) throws {
    try traverse(node)
  }

  func traverse(_ node: Block) throws {
    try visit(node.statements)
  }

  // MARK: Declarations

  func visit(_ node: PropDecl) throws {
    try traverse(node)
  }

  func traverse(_ node: PropDecl) throws {
    if let typeAnnotation = node.typeAnnotation {
      try visit(typeAnnotation)
    }
    if let (_, value) = node.initialBinding {
      try visit(value)
    }
  }

  func visit(_ node: FunDecl) throws {
    try traverse(node)
  }

  func traverse(_ node: FunDecl) throws {
    try visit(node.parameters)
    if let codomain = node.codomain {
      try visit(codomain)
    }
    if let body = node.body {
      try visit(body)
    }
  }

  func visit(_ node: ParamDecl) throws {
    try traverse(node)
  }

  func traverse(_ node: ParamDecl) throws {
    if let annotation = node.typeAnnotation {
      try visit(annotation)
    }
  }

  func visit(_ node: StructDecl) throws {
    try traverse(node)
  }

  func traverse(_ node: StructDecl) throws {
    try visit(node.body)
  }

  func visit(_ node: UnionNestedMemberDecl) throws {
    try traverse(node)
  }

  func traverse(_ node: UnionNestedMemberDecl) throws {
    try visit(node.nominalTypeDecl)
  }

  func visit(_ node: UnionDecl) throws {
    try traverse(node)
  }

  func traverse(_ node: UnionDecl) throws {
    try visit(node.body)
  }

  func visit(_ node: InterfaceDecl) throws {
    try traverse(node)
  }

  func traverse(_ node: InterfaceDecl) throws {
    try visit(node.body)
  }

  // MARK: Type signatures

  func visit(_ node: QualTypeSign) throws {
    try traverse(node)
  }

  func traverse(_ node: QualTypeSign) throws {
    if let signature = node.signature {
      try visit(signature)
    }
  }

  func visit(_ node: TypeIdent) throws {
    try traverse(node)
  }

  func traverse(_ node: TypeIdent) throws {
    try visit(Array(node.specializations.values))
  }

  func visit(_ node: FunSign) throws {
    try traverse(node)
  }

  func traverse(_ node: FunSign) throws {
    try visit(node.parameters)
    try visit(node.codomain)
  }

  func visit(_ node: ParamSign) throws {
    try traverse(node)
  }

  func traverse(_ node: ParamSign) throws {
    try visit(node.typeAnnotation)
  }

  // MARK: Statements

  func visit(_ node: Directive) throws {
  }

  func visit(_ node: WhileLoop) throws {
    try traverse(node)
  }

  func traverse(_ node: WhileLoop) throws {
    try visit(node.condition)
    try visit(node.body)
  }

  func visit(_ node: BindingStmt) throws {
    try traverse(node)
  }

  func traverse(_ node: BindingStmt) throws {
    try visit(node.lvalue)
    try visit(node.rvalue)
  }

  func visit(_ node: ReturnStmt) throws {
    try traverse(node)
  }

  func traverse(_ node: ReturnStmt) throws {
    if let (_, value) = node.binding {
      try visit(value)
    }
  }

  // MARK: Expressions

  func visit(_ node: NullRef) throws {
  }

  func visit(_ node: IfExpr) throws {
    try traverse(node)
  }

  func traverse(_ node: IfExpr) throws {
    try visit(node.condition)
    try visit(node.thenBlock)
    if let elseBlock = node.elseBlock {
      try visit(elseBlock)
    }
  }

  func visit(_ node: LambdaExpr) throws {
    try traverse(node)
  }

  func traverse(_ node: LambdaExpr) throws {
    try visit(node.parameters)
    if let codomain = node.codomain {
      try visit(codomain)
    }
    try visit(node.body)
  }

  func visit(_ node: CastExpr) throws {
    try traverse(node)
  }

  func traverse(_ node: CastExpr) throws {
    try visit(node.operand)
    try visit(node.castType)
  }

  func visit(_ node: BinExpr) throws {
    try traverse(node)
  }

  func traverse(_ node: BinExpr) throws {
    try visit(node.left)
    try visit(node.right)
  }

  func visit(_ node: UnExpr) throws {
    try traverse(node)
  }

  func traverse(_ node: UnExpr) throws {
    try visit(node.operand)
  }

  func visit(_ node: CallExpr) throws {
    try traverse(node)
  }

  func traverse(_ node: CallExpr) throws {
    try visit(node.callee)
    try visit(node.arguments)
  }

  func visit(_ node: CallArg) throws {
    try traverse(node)
  }

  func traverse(_ node: CallArg) throws {
    try visit(node.value)
  }

  func visit(_ node: SubscriptExpr) throws {
    try traverse(node)
  }

  func traverse(_ node: SubscriptExpr) throws {
    try visit(node.callee)
    try visit(node.arguments)
  }

  func visit(_ node: SelectExpr) throws {
    try traverse(node)
  }

  func traverse(_ node: SelectExpr) throws {
    if let owner = node.owner {
      try visit(owner)
    }
    try visit(node.ownee)
  }

  func visit(_ node: Ident) throws {
    try traverse(node)
  }

  func traverse(_ node: Ident) throws {
    try visit(Array(node.specializations.values))
  }

  func visit(_ node: ArrayLiteral) throws {
    try traverse(node)
  }

  func traverse(_ node: ArrayLiteral) throws {
    try visit(node.elements)
  }

  func visit(_ node: SetLiteral) throws {
    try traverse(node)
  }

  func traverse(_ node: SetLiteral) throws {
    try visit(node.elements)
  }

  func visit(_ node: MapLiteral) throws {
    try traverse(node)
  }

  func traverse(_ node: MapLiteral) throws {
    try visit(Array(node.elements.values))
  }

  func visit(_ node: Literal<Bool>) throws {
  }

  func visit(_ node: Literal<Int>) throws {
  }

  func visit(_ node: Literal<Double>) throws {
  }

  func visit(_ node: Literal<String>) throws {
  }

}
