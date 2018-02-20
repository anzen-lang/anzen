public protocol ASTVisitor {

    mutating func visit(_ node: ModuleDecl)      throws
    mutating func visit(_ node: Block)           throws

    // MARK: Declarations

    mutating func visit(_ node: FunDecl)         throws
    mutating func visit(_ node: ParamDecl)       throws
    mutating func visit(_ node: PropDecl)        throws
    mutating func visit(_ node: StructDecl)      throws
    mutating func visit(_ node: InterfaceDecl)   throws
    mutating func visit(_ node: PropReq)         throws
    mutating func visit(_ node: FunReq)          throws

    // MARK: Type signatures

    mutating func visit(_ node: QualSign)        throws
    mutating func visit(_ node: FunSign)         throws
    mutating func visit(_ node: ParamSign)       throws

    // MARK: Statements

    mutating func visit(_ node: BindingStmt)     throws
    mutating func visit(_ node: ReturnStmt)      throws

    // MARK: Expressions

    mutating func visit(_ node: IfExpr)          throws
    mutating func visit(_ node: BinExpr)         throws
    mutating func visit(_ node: UnExpr)          throws
    mutating func visit(_ node: CallExpr)        throws
    mutating func visit(_ node: CallArg)         throws
    mutating func visit(_ node: SubscriptExpr)   throws
    mutating func visit(_ node: SelectExpr)      throws
    mutating func visit(_ node: Ident)           throws
    mutating func visit(_ node: Literal<Int>)    throws
    mutating func visit(_ node: Literal<Bool>)   throws
    mutating func visit(_ node: Literal<String>) throws

}
