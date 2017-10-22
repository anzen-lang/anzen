/// A visitor that extracts the symbols declared in the AST's scopes.
///
/// This visitor annotates the scope-opening nodes (i.e. `Module` and `Block` nodes) with the
/// the symbols that are declared within. This is done so that identifiers referring to functions
/// and types may be used before their formal declaration.
public struct SymbolsExtractor: ASTVisitor {

    @discardableResult
    public mutating func visit(_ node: Module) -> Bool {
        self.nodeStack.append(node)
        try! self.traverse(node)
        _ = self.nodeStack.popLast()

        // Cancel further traversal since we already visited the relevant node's children.
        return false
    }

    @discardableResult
    public mutating func visit(_ node: Block) -> Bool {
        self.nodeStack.append(node)
        try! self.traverse(node)
        self.nodeStack.removeLast()

        // Cancel further traversal since we already visited the relevant node's children.
        return false
    }

    @discardableResult
    public mutating func visit(_ node: FunDecl) -> Bool {
        var block = self.nodeStack.last
        block?.symbols.insert(node.name)

        // We push the function's block onto the node stack before visiting its parameters, so
        // that they get properly declared within the function's scope rather than that of the
        // function itself.
        self.nodeStack.append(node.body as! Block)
        for parameter in node.parameters {
            try! self.traverse(parameter)
        }
        try! self.traverse(node.body)
        self.nodeStack.removeLast()

        // Cancel further traversal since we already visited the relevant node's children.
        return false
    }

    @discardableResult
    public mutating func visit(_ node: ParamDecl) -> Bool {
        var block = self.nodeStack.last
        block?.symbols.insert(node.name)
        return true
    }

    @discardableResult
    public mutating func visit(_ node: PropDecl) -> Bool {
        var block = self.nodeStack.last
        block?.symbols.insert(node.name)
        return true
    }

    @discardableResult
    public mutating func visit(_ node: StructDecl) -> Bool {
        print(node)
        var block = self.nodeStack.last
        block?.symbols.insert(node.name)
        return true
    }

    var nodeStack: [ScopeOpeningNode] = []

}
