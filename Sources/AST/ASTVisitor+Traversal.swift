public extension ASTVisitor {

  // swiftlint:disable cyclomatic_complexity
  mutating func visit(_ node: Node) throws {
    switch node {
    case let n as ModuleDecl:      try visit(n)
    case let n as Block:           try visit(n)
    case let n as PropDecl:        try visit(n)
    case let n as FunDecl:         try visit(n)
    case let n as ParamDecl:       try visit(n)
    case let n as StructDecl:      try visit(n)
    case let n as InterfaceDecl:   try visit(n)
    case let n as QualSign:        try visit(n)
    case let n as FunSign:         try visit(n)
    case let n as ParamSign:       try visit(n)
    case let n as BindingStmt:     try visit(n)
    case let n as ReturnStmt:      try visit(n)
    case let n as IfExpr:          try visit(n)
    case let n as LambdaExpr:      try visit(n)
    case let n as BinExpr:         try visit(n)
    case let n as UnExpr:          try visit(n)
    case let n as CallExpr:        try visit(n)
    case let n as CallArg:         try visit(n)
    case let n as SubscriptExpr:   try visit(n)
    case let n as SelectExpr:      try visit(n)
    case let n as Ident:           try visit(n)
    case let n as ArrayLiteral:    try visit(n)
    case let n as SetLiteral:      try visit(n)
    case let n as MapLiteral:      try visit(n)
    case let n as Literal<Bool>:   try visit(n)
    case let n as Literal<Int>:    try visit(n)
    case let n as Literal<Double>: try visit(n)
    case let n as Literal<String>: try visit(n)
    default:
      assertionFailure("unexpected node during generic visit")
    }
  }
  // swiftlint:enable cyclomatic_complexity

  mutating func visit(_ nodes: [Node]) throws {
    for node in nodes {
      try visit(node)
    }
  }

  mutating func visit(_ node: ModuleDecl) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: ModuleDecl) throws {
    try visit(node.statements)
  }

  mutating func visit(_ node: Block) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: Block) throws {
    try visit(node.statements)
  }

  // MARK: Declarations

  mutating func visit(_ node: PropDecl) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: PropDecl) throws {
    if let typeAnnotation = node.typeAnnotation {
      try visit(typeAnnotation)
    }
    if let (_, value) = node.initialBinding {
      try visit(value)
    }
  }

  mutating func visit(_ node: FunDecl) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: FunDecl) throws {
    try visit(node.parameters)
    if let codomain = node.codomain {
      try visit(codomain)
    }
    if let body = node.body {
      try visit(body)
    }
  }

  mutating func visit(_ node: ParamDecl) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: ParamDecl) throws {
    if let annotation = node.typeAnnotation {
      try visit(annotation)
    }
  }

  mutating func visit(_ node: StructDecl) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: StructDecl) throws {
    try visit(node.body)
  }

  mutating func visit(_ node: InterfaceDecl) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: InterfaceDecl) throws {
    try visit(node.body)
  }

  // MARK: Type signatures

  mutating func visit(_ node: QualSign) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: QualSign) throws {
    if let signature = node.signature {
      try visit(signature)
    }
  }

  mutating func visit(_ node: FunSign) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: FunSign) throws {
    try visit(node.parameters)
    try visit(node.codomain)
  }

  mutating func visit(_ node: ParamSign) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: ParamSign) throws {
    try visit(node.typeAnnotation)
  }

  // MARK: Statements

  mutating func visit(_ node: BindingStmt) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: BindingStmt) throws {
    try visit(node.lvalue)
    try visit(node.rvalue)
  }

  mutating func visit(_ node: ReturnStmt) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: ReturnStmt) throws {
    if let value = node.value {
      try visit(value)
    }
  }

  // MARK: Expressions

  mutating func visit(_ node: IfExpr) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: IfExpr) throws {
    try visit(node.condition)
    try visit(node.thenBlock)
    if let elseBlock = node.elseBlock {
      try visit(elseBlock)
    }
  }

  mutating func visit(_ node: LambdaExpr) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: LambdaExpr) throws {
    try visit(node.parameters)
    if let codomain = node.codomain {
      try visit(codomain)
    }
    try visit(node.body)
  }

  mutating func visit(_ node: BinExpr) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: BinExpr) throws {
    try visit(node.left)
    try visit(node.right)
  }

  mutating func visit(_ node: UnExpr) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: UnExpr) throws {
    try visit(node.operand)
  }

  mutating func visit(_ node: CallExpr) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: CallExpr) throws {
    try visit(node.callee)
    try visit(node.arguments)
  }

  mutating func visit(_ node: CallArg) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: CallArg) throws {
    try visit(node.value)
  }

  mutating func visit(_ node: SubscriptExpr) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: SubscriptExpr) throws {
    try visit(node.callee)
    try visit(node.arguments)
  }

  mutating func visit(_ node: SelectExpr) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: SelectExpr) throws {
    if let owner = node.owner {
      try visit(owner)
    }
    try visit(node.ownee)
  }

  mutating func visit(_ node: Ident) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: Ident) throws {
    try visit(Array(node.specializations.values))
  }

  mutating func visit(_ node: ArrayLiteral) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: ArrayLiteral) throws {
    try visit(node.elements)
  }

  mutating func visit(_ node: SetLiteral) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: SetLiteral) throws {
    try visit(node.elements)
  }

  mutating func visit(_ node: MapLiteral) throws {
    try traverse(node)
  }

  mutating func traverse(_ node: MapLiteral) throws {
    try visit(Array(node.elements.values))
  }

  mutating func visit(_ node: Literal<Bool>) throws {
  }

  mutating func visit(_ node: Literal<Int>) throws {
  }

  mutating func visit(_ node: Literal<Double>) throws {
  }

  mutating func visit(_ node: Literal<String>) throws {
  }

}
