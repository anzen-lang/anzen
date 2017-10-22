public protocol ASTVisitor {

    mutating func visit(node: Module)        throws -> Bool
    mutating func visit(node: Block)         throws -> Bool

    // MARK: Declarations

    mutating func visit(node: FunDecl)       throws -> Bool
    mutating func visit(node: ParamDecl)     throws -> Bool
    mutating func visit(node: PropDecl)      throws -> Bool
    mutating func visit(node: StructDecl)    throws -> Bool

    // MARK: Type signatures

    mutating func visit(node: QualSign)      throws -> Bool
    mutating func visit(node: FunSign)       throws -> Bool
    mutating func visit(node: ParamSign)     throws -> Bool

    // MARK: Statements

    mutating func visit(node: BindingStmt)   throws -> Bool
    mutating func visit(node: ReturnStmt)    throws -> Bool

    // MARK: Expressions

    mutating func visit(node: IfExpr)        throws -> Bool
    mutating func visit(node: BinExpr)       throws -> Bool
    mutating func visit(node: UnExpr)        throws -> Bool
    mutating func visit(node: CallExpr)      throws -> Bool
    mutating func visit(node: CallArg)       throws -> Bool
    mutating func visit(node: SubscriptExpr) throws -> Bool
    mutating func visit(node: SelectExpr)    throws -> Bool
    mutating func visit(node: Ident)         throws -> Bool
    mutating func visit<T>(node: Literal<T>) throws -> Bool

}

public extension ASTVisitor {

    mutating func visit(node: Module) throws -> Bool {
        return true
    }

    mutating func visit(node: Block) throws -> Bool {
        return true
    }

    // MARK: Declarations

    mutating func visit(node: FunDecl) throws -> Bool {
        return true
    }

    mutating func visit(node: ParamDecl) throws -> Bool {
        return true
    }

    mutating func visit(node: PropDecl) throws -> Bool {
        return true
    }

    mutating func visit(node: StructDecl) throws -> Bool {
        return true
    }

    // MARK: Type signatures

    mutating func visit(node: QualSign) throws -> Bool {
        return true
    }

    mutating func visit(node: FunSign) throws -> Bool {
        return true
    }

    mutating func visit(node: ParamSign) throws -> Bool {
        return true
    }

    // MARK: Statements

    mutating func visit(node: BindingStmt) throws -> Bool {
        return true
    }

    mutating func visit(node: ReturnStmt) throws -> Bool {
        return true
    }

    // MARK: Expressions

    mutating func visit(node: IfExpr) throws -> Bool {
        return true
    }

    mutating func visit(node: BinExpr) throws -> Bool {
        return true
    }

    mutating func visit(node: UnExpr) throws -> Bool {
        return true
    }

    mutating func visit(node: CallExpr) throws -> Bool {
        return true
    }

    mutating func visit(node: CallArg) throws -> Bool {
        return true
    }

    mutating func visit(node: SubscriptExpr) throws -> Bool {
        return true
    }

    mutating func visit(node: SelectExpr) throws -> Bool {
        return true
    }

    mutating func visit(node: Ident) throws -> Bool {
        return true
    }

    mutating func visit<T>(node: Literal<T>) throws -> Bool {
        return true
    }

}
