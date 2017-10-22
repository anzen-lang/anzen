public protocol ASTVisitor {

    @discardableResult mutating func visit(_ node: Module)        throws -> Bool
    @discardableResult mutating func visit(_ node: Block)         throws -> Bool

    // MARK: Declarations

    @discardableResult mutating func visit(_ node: FunDecl)       throws -> Bool
    @discardableResult mutating func visit(_ node: ParamDecl)     throws -> Bool
    @discardableResult mutating func visit(_ node: PropDecl)      throws -> Bool
    @discardableResult mutating func visit(_ node: StructDecl)    throws -> Bool

    // MARK: Type signatures

    @discardableResult mutating func visit(_ node: QualSign)      throws -> Bool
    @discardableResult mutating func visit(_ node: FunSign)       throws -> Bool
    @discardableResult mutating func visit(_ node: ParamSign)     throws -> Bool

    // MARK: Statements

    @discardableResult mutating func visit(_ node: BindingStmt)   throws -> Bool
    @discardableResult mutating func visit(_ node: ReturnStmt)    throws -> Bool

    // MARK: Expressions

    @discardableResult mutating func visit(_ node: IfExpr)        throws -> Bool
    @discardableResult mutating func visit(_ node: BinExpr)       throws -> Bool
    @discardableResult mutating func visit(_ node: UnExpr)        throws -> Bool
    @discardableResult mutating func visit(_ node: CallExpr)      throws -> Bool
    @discardableResult mutating func visit(_ node: CallArg)       throws -> Bool
    @discardableResult mutating func visit(_ node: SubscriptExpr) throws -> Bool
    @discardableResult mutating func visit(_ node: SelectExpr)    throws -> Bool
    @discardableResult mutating func visit(_ node: Ident)         throws -> Bool
    @discardableResult mutating func visit<T>(_ node: Literal<T>) throws -> Bool

}

public extension ASTVisitor {

    @discardableResult
    mutating func visit(_ node: Module) throws -> Bool {
        return true
    }

    @discardableResult
    mutating func visit(_ node: Block) throws -> Bool {
        return true
    }

    // MARK: Declarations

    @discardableResult
    mutating func visit(_ node: FunDecl) throws -> Bool {
        return true
    }

    @discardableResult
    mutating func visit(_ node: ParamDecl) throws -> Bool {
        return true
    }

    @discardableResult
    mutating func visit(_ node: PropDecl) throws -> Bool {
        return true
    }

    @discardableResult
    mutating func visit(_ node: StructDecl) throws -> Bool {
        return true
    }

    // MARK: Type signatures

    @discardableResult
    mutating func visit(_ node: QualSign) throws -> Bool {
        return true
    }

    @discardableResult
    mutating func visit(_ node: FunSign) throws -> Bool {
        return true
    }

    @discardableResult
    mutating func visit(_ node: ParamSign) throws -> Bool {
        return true
    }

    // MARK: Statements

    @discardableResult
    mutating func visit(_ node: BindingStmt) throws -> Bool {
        return true
    }

    @discardableResult
    mutating func visit(_ node: ReturnStmt) throws -> Bool {
        return true
    }

    // MARK: Expressions

    @discardableResult
    mutating func visit(_ node: IfExpr) throws -> Bool {
        return true
    }

    @discardableResult
    mutating func visit(_ node: BinExpr) throws -> Bool {
        return true
    }

    @discardableResult
    mutating func visit(_ node: UnExpr) throws -> Bool {
        return true
    }

    @discardableResult
    mutating func visit(_ node: CallExpr) throws -> Bool {
        return true
    }

    @discardableResult
    mutating func visit(_ node: CallArg) throws -> Bool {
        return true
    }

    @discardableResult
    mutating func visit(_ node: SubscriptExpr) throws -> Bool {
        return true
    }

    @discardableResult
    mutating func visit(_ node: SelectExpr) throws -> Bool {
        return true
    }

    @discardableResult
    mutating func visit(_ node: Ident) throws -> Bool {
        return true
    }

    @discardableResult
    mutating func visit<T>(node: Literal<T>) throws -> Bool {
        return true
    }

}
