public struct SymbolsExtractor: ASTVisitor {

    @discardableResult
    public mutating func visit(_ node: Module) -> Bool {
        self.nodeStack.append(node)
        try! self.traverse(node)
        _ = self.nodeStack.popLast()
        return true
    }

    @discardableResult
    public mutating func visit(_ node: Block) -> Bool {
        self.nodeStack.append(node)
        try! self.traverse(node)
        self.nodeStack.removeLast()
        return true
    }

    @discardableResult
    public mutating func visit(_ node: FunDecl) -> Bool {
        var block = self.nodeStack.last
        block?.symbols.insert(node.name)

        // Note that we push the function's block onto the node stack before we visit its
        // parameters, so that they get properly declared within the function's scope rather
        // than that of the function itself.
        self.nodeStack.append(node.body as! Block)
        for parameter in node.parameters {
            try! self.traverse(parameter)
        }
        try! self.traverse(node.body)
        self.nodeStack.removeLast()

        return try! self.traverse(node)
    }

    @discardableResult
    public mutating func visit(_ node: ParamDecl) -> Bool {
        var block = self.nodeStack.last
        block?.symbols.insert(node.name)
        return try! self.traverse(node)
    }

    @discardableResult
    public mutating func visit(_ node: PropDecl) -> Bool {
        var block = self.nodeStack.last
        block?.symbols.insert(node.name)
        return try! self.traverse(node)
    }

    @discardableResult
    public mutating func visit(_ node: StructDecl) -> Bool {
        var block = self.nodeStack.last
        block?.symbols.insert(node.name)
        return try! self.traverse(node)
    }

    var nodeStack: [ScopeOpeningNode] = []

}
