public extension ASTVisitor {

    @discardableResult
    mutating func traverse(_ node: Node) throws -> Bool {
        switch node {
        case let n as Module:
            return try self.traverse(n)
        case let n as Block:
            return try self.traverse(n)
        case let n as FunDecl:
            return try self.traverse(n)
        case let n as ParamDecl:
            return try self.traverse(n)
        case let n as PropDecl:
            return try self.traverse(n)
        case let n as StructDecl:
            return try self.traverse(n)
        case let n as QualSign:
            return try self.traverse(n)
        case let n as FunSign:
            return try self.traverse(n)
        case let n as ParamSign:
            return try self.traverse(n)
        case let n as BindingStmt:
            return try self.traverse(n)
        case let n as ReturnStmt:
            return try self.traverse(n)
        case let n as IfExpr:
            return try self.traverse(n)
        case let n as BinExpr:
            return try self.traverse(n)
        case let n as UnExpr:
            return try self.traverse(n)
        case let n as CallExpr:
            return try self.traverse(n)
        case let n as CallArg:
            return try self.traverse(n)
        case let n as SubscriptExpr:
            return try self.traverse(n)
        case let n as SelectExpr:
            return try self.traverse(n)
        case let n as Ident:
            return try self.traverse(n)
        case let n as Literal<Any>:
            return try self.traverse(n)
        default:
            assertionFailure("unexpected node during traversal")
        }

        return true
    }

    @discardableResult
    mutating func traverse(_ nodes: [Node]) throws -> Bool {
        for node in nodes {
            guard try self.traverse(node) else { return false }
        }
        return true
    }

    @discardableResult
    mutating func traverse(_ node: Module) throws -> Bool {
        guard try self.visit(node) else { return false }

        return try self.traverse(node.statements)
    }

    @discardableResult
    mutating func traverse(_ node: Block) throws -> Bool {
        guard try self.visit(node) else { return false }

        return try self.traverse(node.statements)
    }

    // MARK: Declarations

    @discardableResult
    mutating func traverse(_ node: FunDecl) throws -> Bool {
        guard try self.visit(node) else { return false }

        guard try self.traverse(node.parameters) else { return false }
        if let codomain = node.codomain {
            guard try self.traverse(codomain) else { return false }
        }
        guard try self.traverse(node.body) else { return false }

        return true
    }

    @discardableResult
    mutating func traverse(_ node: ParamDecl) throws -> Bool {
        guard try self.visit(node) else { return false }

        guard try self.traverse(node.typeAnnotation) else { return false }

        return true
    }

    @discardableResult
    mutating func traverse(_ node: PropDecl) throws -> Bool {
        guard try self.visit(node) else { return false }

        if let typeAnnotation = node.typeAnnotation {
            guard try self.traverse(typeAnnotation) else { return false }
        }
        if let (_, value) = node.initialBinding {
            guard try self.traverse(value) else { return false }
        }

        return true
    }

    @discardableResult
    mutating func traverse(_ node: StructDecl) throws -> Bool {
        guard try self.visit(node) else { return false }

        guard try self.traverse(node.body) else { return false }

        return true
    }

    // MARK: Type signatures

    @discardableResult
    mutating func traverse(_ node: QualSign) throws -> Bool {
        guard try self.visit(node) else { return false }

        if let signature = node.signature {
            guard try self.traverse(signature) else { return false }
        }

        return true
    }

    @discardableResult
    mutating func traverse(_ node: FunSign) throws -> Bool {
        guard try self.visit(node) else { return false }

        guard try self.traverse(node.parameters) else { return false }
        guard try self.traverse(node.codomain) else { return false }

        return true
    }

    @discardableResult
    mutating func traverse(_ node: ParamSign) throws -> Bool {
        guard try self.visit(node) else { return false }

        guard try self.traverse(node.typeAnnotation) else { return false }

        return true
    }

    // MARK: Statements

    @discardableResult
    mutating func traverse(_ node: BindingStmt) throws -> Bool {
        guard try self.visit(node) else { return false }

        guard try self.traverse(node.lvalue) else { return false }
        guard try self.traverse(node.rvalue) else { return false }

        return true
    }

    @discardableResult
    mutating func traverse(_ node: ReturnStmt) throws -> Bool {
        guard try self.visit(node) else { return false }

        if let value = node.value {
            guard try self.traverse(value) else { return false }
        }

        return true
    }

    // MARK: Expressions

    @discardableResult
    mutating func traverse(_ node: IfExpr) throws -> Bool {
        guard try self.visit(node) else { return false }

        guard try self.traverse(node.condition) else { return false }
        guard try self.traverse(node.thenBlock) else { return false }
        if let elseBlock = node.elseBlock {
            guard try self.traverse(elseBlock) else { return false }
        }

        return true
    }

    @discardableResult
    mutating func traverse(_ node: BinExpr) throws -> Bool {
        guard try self.visit(node) else { return false }

        guard try self.traverse(node.left) else { return false }
        guard try self.traverse(node.right) else { return false }

        return true
    }

    @discardableResult
    mutating func traverse(_ node: UnExpr) throws -> Bool {
        guard try self.visit(node) else { return false }

        guard try self.traverse(node.operand) else { return false }

        return true
    }

    @discardableResult
    mutating func traverse(_ node: CallExpr) throws -> Bool {
        guard try self.visit(node) else { return false }

        guard try self.traverse(node.callee) else { return false }
        guard try self.traverse(node.arguments) else { return false }

        return true
    }

    @discardableResult
    mutating func traverse(_ node: CallArg) throws -> Bool {
        guard try self.visit(node) else { return false }

        guard try self.traverse(node.value) else { return false }

        return true
    }

    @discardableResult
    mutating func traverse(_ node: SubscriptExpr) throws -> Bool {
        guard try self.visit(node) else { return false }

        guard try self.traverse(node.callee) else { return false }
        guard try self.traverse(node.arguments) else { return false }

        return true
    }

    @discardableResult
    mutating func traverse(_ node: SelectExpr) throws -> Bool {
        guard try self.visit(node) else { return false }

        if let owner = node.owner {
            guard try self.traverse(owner) else { return false }
        }
        guard try self.traverse(node.member) else { return false }

        return true
    }

    @discardableResult
    mutating func traverse(_ node: Ident) throws -> Bool {
        guard try self.visit(node) else { return false }

        return true
    }

    @discardableResult
    mutating func traverse<T>(_ node: Literal<T>) throws -> Bool {
        guard try self.visit(node) else { return false }

        return true
    }

}
