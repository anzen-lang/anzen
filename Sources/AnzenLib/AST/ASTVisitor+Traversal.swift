public extension ASTVisitor {

    mutating func traverse(_ node: Node) throws {
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
            assertionFailure("unexpected node during traversal")
        }
    }
    
    mutating func traverse(_ nodes: [Node]) throws {
        for node in nodes {
            try self.traverse(node)
        }
    }

    mutating func visit(_ node: ModuleDecl) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: ModuleDecl) throws {
        try self.traverse(node.statements)
    }

    mutating func visit(_ node: Block) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: Block) throws {
        try self.traverse(node.statements)
    }

    // MARK: Declarations

    mutating func visit(_ node: FunDecl) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: FunDecl) throws {
        try self.traverse(node.parameters)
        if let codomain = node.codomain {
            try self.traverse(codomain)
        }
        try self.traverse(node.body)
    }

    mutating func visit(_ node: ParamDecl) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: ParamDecl) throws {
        try self.traverse(node.typeAnnotation)
    }

    mutating func visit(_ node: PropDecl) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: PropDecl) throws {
        if let typeAnnotation = node.typeAnnotation {
            try self.traverse(typeAnnotation)
        }
        if let (_, value) = node.initialBinding {
            try self.traverse(value)
        }
    }

    mutating func visit(_ node: StructDecl) throws {
        try self.traverse(node)
    }
    
    mutating func traverse(_ node: StructDecl) throws {
        try self.traverse(node.body)
    }

    // MARK: Type signatures

    mutating func visit(_ node: QualSign) throws {
        try self.traverse(node)
    }
    
    mutating func traverse(_ node: QualSign) throws {
        if let signature = node.signature {
            try self.traverse(signature)
        }
    }

    mutating func visit(_ node: FunSign) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: FunSign) throws {
        try self.traverse(node.parameters)
        try self.traverse(node.codomain)
    }

    mutating func visit(_ node: ParamSign) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: ParamSign) throws {
        try self.traverse(node.typeAnnotation)
    }

    // MARK: Statements

    mutating func visit(_ node: BindingStmt) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: BindingStmt) throws {
        try self.traverse(node.lvalue)
        try self.traverse(node.rvalue)
    }

    mutating func visit(_ node: ReturnStmt) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: ReturnStmt) throws {
        if let value = node.value {
            try self.traverse(value)
        }
    }

    // MARK: Expressions

    mutating func visit(_ node: IfExpr) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: IfExpr) throws {
        try self.traverse(node.condition)
        try self.traverse(node.thenBlock)
        if let elseBlock = node.elseBlock {
            try self.traverse(elseBlock)
        }
    }

    mutating func visit(_ node: BinExpr) throws {
        try self.traverse(node)
    }
    
    mutating func traverse(_ node: BinExpr) throws {
        try self.traverse(node.left)
        try self.traverse(node.right)
    }

    mutating func visit(_ node: UnExpr) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: UnExpr) throws {
        try self.traverse(node.operand)
    }

    mutating func visit(_ node: CallExpr) throws {
        try self.traverse(node)
    }
    
    mutating func traverse(_ node: CallExpr) throws {
        try self.traverse(node.callee)
        try self.traverse(node.arguments)
    }

    mutating func visit(_ node: CallArg) throws {
        try self.traverse(node)
    }
    
    mutating func traverse(_ node: CallArg) throws {
        try self.traverse(node.value)
    }

    mutating func visit(_ node: SubscriptExpr) throws {
        try self.traverse(node)
    }
    
    mutating func traverse(_ node: SubscriptExpr) throws {
        try self.traverse(node.callee)
        try self.traverse(node.arguments)
    }

    mutating func visit(_ node: SelectExpr) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: SelectExpr) throws {
        if let owner = node.owner {
            try self.traverse(owner)
        }
        try self.traverse(node.ownee)
    }

    mutating func visit(_ node: Ident) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: Ident) throws {
    }

    mutating func visit(_ node: Literal<Int>) throws {
        try self.traverse(node)
    }
    
    mutating func traverse(_ node: Literal<Int>) throws {
    }

    mutating func visit(_ node: Literal<Bool>) throws {
        try self.traverse(node)
    }

    mutating func traverse(_ node: Literal<Bool>) throws {
    }

    mutating func visit(_ node: Literal<String>) throws {
        try self.traverse(node)
    }
    
    mutating func traverse(_ node: Literal<String>) throws {
    }

}
