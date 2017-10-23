/// A visitor that extracts the symbols declared in the AST's scopes.
///
/// This visitor annotates the scope-opening nodes (i.e. `Module` and `Block` nodes) with the
/// the symbols that are declared within. This is done so that identifiers referring to functions
/// and types may be used before their formal declaration.
public struct SymbolsExtractor: ASTVisitor {

    public mutating func visit(_ node: ModuleDecl) {
        self.nodeStack.push(node)
        try! self.traverse(node)
        self.nodeStack.pop()
    }

    public mutating func visit(_ node: Block) {
        self.nodeStack.push(node)
        try! self.traverse(node)
        self.nodeStack.pop()
    }

    public mutating func visit(_ node: FunDecl) {
        self.nodeStack.last.symbols.insert(node.name)

        // We push the function's block onto the node stack before visiting its parameters, so
        // that they get properly declared within the function's scope rather than that of the
        // function itself.
        self.nodeStack.push(node.body as! Block)
        try! self.traverse(node.parameters)
        try! self.traverse((node.body as! Block).statements)
        self.nodeStack.pop()
    }

    public mutating func visit(_ node: ParamDecl) {
        self.nodeStack.last.symbols.insert(node.name)
        try! self.traverse(node)
    }

    public mutating func visit(_ node: PropDecl) {
        self.nodeStack.last.symbols.insert(node.name)
        try! self.traverse(node)
    }

    public mutating func visit(_ node: StructDecl) {
        self.nodeStack.last.symbols.insert(node.name)
        try! self.traverse(node)
    }

    // MARK: Internals

    var nodeStack: Stack<ScopeOpeningNode> = []

}
