public extension ASTVisitor {

    mutating func visit(_ node: Node) throws {
        switch node {
        case let n as ModuleDecl:      try self.visit(n)
        case let n as Block:           try self.visit(n)
        case let n as FunDecl:         try self.visit(n)
        case let n as ParamDecl:       try self.visit(n)
        case let n as PropDecl:        try self.visit(n)
        case let n as StructDecl:      try self.visit(n)
        case let n as QualSign:        try self.visit(n)
        case let n as FunSign:         try self.visit(n)
        case let n as ParamSign:       try self.visit(n)
        case let n as BindingStmt:     try self.visit(n)
        case let n as ReturnStmt:      try self.visit(n)
        case let n as IfExpr:          try self.visit(n)
        case let n as BinExpr:         try self.visit(n)
        case let n as UnExpr:          try self.visit(n)
        case let n as CallExpr:        try self.visit(n)
        case let n as CallArg:         try self.visit(n)
        case let n as SubscriptExpr:   try self.visit(n)
        case let n as SelectExpr:      try self.visit(n)
        case let n as Ident:           try self.visit(n)
        case let n as Literal<Int>:    try self.visit(n)
        case let n as Literal<Bool>:   try self.visit(n)
        case let n as Literal<String>: try self.visit(n)
        default:
            assertionFailure("unexpected node during generic visit")
        }
    }
    
    mutating func visit(_ nodes: [Node]) throws {
        for node in nodes {
            try self.visit(node)
        }
    }

    mutating func visit(_ node: ModuleDecl) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: ModuleDecl) throws {
        try self.visit(node.statements)
    }

    mutating func visit(_ node: Block) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: Block) throws {
        try self.visit(node.statements)
    }

    // MARK: Declarations

    mutating func visit(_ node: FunDecl) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: FunDecl) throws {
        try self.visit(node.parameters)
        if let codomain = node.codomain {
            try self.visit(codomain)
        }
        try self.visit(node.body)
    }

    mutating func visit(_ node: ParamDecl) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: ParamDecl) throws {
        try self.visit(node.typeAnnotation)
    }

    mutating func visit(_ node: PropDecl) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: PropDecl) throws {
        if let typeAnnotation = node.typeAnnotation {
            try self.visit(typeAnnotation)
        }
        if let (_, value) = node.initialBinding {
            try self.visit(value)
        }
    }

    mutating func visit(_ node: StructDecl) throws {
        try self.traverse(node)
    }
    
    mutating func traverse(_ node: StructDecl) throws {
        try self.visit(node.body)
    }

    // MARK: Type signatures

    mutating func visit(_ node: QualSign) throws {
        try self.traverse(node)
    }
    
    mutating func traverse(_ node: QualSign) throws {
        if let signature = node.signature {
            try self.visit(signature)
        }
    }

    mutating func visit(_ node: FunSign) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: FunSign) throws {
        try self.visit(node.parameters)
        try self.visit(node.codomain)
    }

    mutating func visit(_ node: ParamSign) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: ParamSign) throws {
        try self.visit(node.typeAnnotation)
    }

    // MARK: Statements

    mutating func visit(_ node: BindingStmt) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: BindingStmt) throws {
        try self.visit(node.lvalue)
        try self.visit(node.rvalue)
    }

    mutating func visit(_ node: ReturnStmt) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: ReturnStmt) throws {
        if let value = node.value {
            try self.visit(value)
        }
    }

    // MARK: Expressions

    mutating func visit(_ node: IfExpr) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: IfExpr) throws {
        try self.visit(node.condition)
        try self.visit(node.thenBlock)
        if let elseBlock = node.elseBlock {
            try self.visit(elseBlock)
        }
    }

    mutating func visit(_ node: BinExpr) throws {
        try self.traverse(node)
    }
    
    mutating func traverse(_ node: BinExpr) throws {
        try self.visit(node.left)
        try self.visit(node.right)
    }

    mutating func visit(_ node: UnExpr) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: UnExpr) throws {
        try self.visit(node.operand)
    }

    mutating func visit(_ node: CallExpr) throws {
        try self.traverse(node)
    }
    
    mutating func traverse(_ node: CallExpr) throws {
        try self.visit(node.callee)
        try self.visit(node.arguments)
    }

    mutating func visit(_ node: CallArg) throws {
        try self.traverse(node)
    }
    
    mutating func traverse(_ node: CallArg) throws {
        try self.visit(node.value)
    }

    mutating func visit(_ node: SubscriptExpr) throws {
        try self.traverse(node)
    }
    
    mutating func traverse(_ node: SubscriptExpr) throws {
        try self.visit(node.callee)
        try self.visit(node.arguments)
    }

    mutating func visit(_ node: SelectExpr) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: SelectExpr) throws {
        if let owner = node.owner {
            try self.visit(owner)
        }
        try self.visit(node.ownee)
    }

    mutating func visit(_ node: Ident) throws {
    }

    mutating func visit(_ node: Literal<Int>) throws {
    }

    mutating func visit(_ node: Literal<Bool>) throws {
    }

    mutating func visit(_ node: Literal<String>) throws {
    }

}
