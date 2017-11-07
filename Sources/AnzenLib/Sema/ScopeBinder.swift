public struct ScopeBinder: ASTVisitor {

    public mutating func visit(_ node: ModuleDecl) throws {
        // Create a scope for the module.
        self.scopes.push(Scope(name: "module", parent: self.scopes.last))
        self.underDeclaration[self.scopes.last] = []

        // Add a new symbol for each entity declared within the node's scope.
        for name in node.symbols {
            self.scopes.last.add(symbol: Symbol(name: name))
        }

        // Visit the node's children.
        try self.traverse(node)
        self.scopes.pop()
    }

    public mutating func visit(_ node: Block) throws {
        // Create a scope for the block.
        self.scopes.push(Scope(name: "block", parent: self.scopes.last))
        self.underDeclaration[self.scopes.last] = []

        // Add a new symbol for each entity declared within the block's scope.
        for name in node.symbols {
            self.scopes.last.add(symbol: Symbol(name: name))
        }

        // Visit the node's children.
        try self.traverse(node)
        self.scopes.pop()
    }

    public mutating func visit(_ node: FunDecl) throws {
        // There should be at least one symbol named after the node's name, set by the visit of
        // the node that opened the scope of this declaration.
        let symbols = self.scopes.last[node.name]
        assert(symbols.count >= 1)

        // If the function's identifer was already declared within the current scope, we make sure
        // the symbol is overloadable.
        guard (symbols[0].node == nil) || (symbols[0].isOverloadable) else {
            throw CompilerError.duplicateDeclaration(name: node.name, location: node.location)
        }

        // If the symbol's already associated with a function declaration, we're visiting an
        // overload. Therefore we should create a new symbol.
        if symbols[0].node != nil {
            self.scopes.last.add(symbol: Symbol(name: node.name))
        }

        // Bind the symbol to the current node.
        symbols.last!.node = node
        symbols.last!.isOverloadable = true
        node.scope = self.scopes.last

        // Create a scope for the function before visiting its signature and body.
        self.scopes.push(Scope(name: node.name, parent: self.scopes.last))
        self.underDeclaration[self.scopes.last] = []
        node.innerScope = self.scopes.last

        // Add a new symbol for each of the function's generic placeholders.
        for placeholder in node.placeholders {
            self.scopes.last.add(symbol: Symbol(name: placeholder))
        }

        // Visit the function's signature **before** visiting the its body, so that we may not
        // bind a parameter to a declaration from the function's body.
        for parameter in node.parameters {
            assert(parameter is ParamDecl)
            self.scopes.last.add(symbol: Symbol(name: (parameter as! ParamDecl).name))
        }
        try self.traverse(node.parameters)
        if let codomain = node.codomain {
            try self.traverse(codomain)
        }

        // FIXME: When we'll implement parameter default values, we'll also have to make sure that
        // the identifiers in the default value don't get bound to other parameters. For instance,
        // the following should throw `undefinedSymbol`:
        //
        //     function f(x: Int = y, y: Int) {}
        //

        // Once we visited the function's signature, we can visit its body.
        for name in node.body.symbols {
            if !self.scopes.last.defines(name: name) {
                self.scopes.last.add(symbol: Symbol(name: name))
            }
        }
        try self.traverse(node.body)
        self.scopes.pop()
    }

    public mutating func visit(_ node: ParamDecl) throws {
        // There should be at least one symbol named after the node's name, set by the visit of
        // the node that opened the scope of this declaration.
        var symbols = self.scopes.last[node.name]
        assert(symbols.count >= 1)

        // Make sure the parameter's name wasn't already declared.
        guard symbols[0].node == nil else {
            throw CompilerError.duplicateDeclaration(name: node.name, location: node.location)
        }

        // Bind the symbol to the current node.
        symbols[0].node = node
        node.scope = self.scopes.last

        // Visit the node's children.
        self.underDeclaration[self.scopes.last]?.insert(node.name)
        try self.traverse(node)
        self.underDeclaration[self.scopes.last]?.remove(node.name)
    }

    public mutating func visit(_ node: PropDecl) throws {
        // There should be at least one symbol named after the node's name, set by the visit of
        // the node that opened the scope of this declaration.
        var symbols = self.scopes.last[node.name]
        assert(symbols.count >= 1)

        // Make sure the property's name wasn't already declared.
        guard symbols[0].node == nil else {
            throw CompilerError.duplicateDeclaration(name: node.name, location: node.location)
        }

        // Bind the symbol to the current node.
        symbols[0].node = node
        node.scope = self.scopes.last

        // Visit the node's children.
        self.underDeclaration[self.scopes.last]?.insert(node.name)
        try self.traverse(node)
        self.underDeclaration[self.scopes.last]?.remove(node.name)
    }

    public mutating func visit(_ node: StructDecl) throws {
        // There should be at least one symbol named after the node's name, set by the visit of
        // the node that opened the scope of this declaration.
        var symbols = self.scopes.last[node.name]
        assert(symbols.count >= 1)

        // Make sure the struct's name wasn't already declared.
        guard symbols[0].node == nil else {
            throw CompilerError.duplicateDeclaration(name: node.name, location: node.location)
        }

        // Bind the symbol to the current node.
        symbols[0].node = node
        node.scope = self.scopes.last

        // Create a scope for the struct before visiting its body.
        self.scopes.push(Scope(name: node.name, parent: self.scopes.last))
        self.underDeclaration[self.scopes.last] = []

        // Introduce a `Self` symbol in the type's scope, to handle the `Self` placeholder.
        let selfSymbol = Symbol(name: "Self")
        selfSymbol.node = node
        self.scopes.last.add(symbol: selfSymbol)

        // Add a new symbol for each of the struct's member and generic placeholders.
        for name in node.body.symbols.union(node.placeholders) {
            self.scopes.last.add(symbol: Symbol(name: name))
        }

        // Visit the node's body.
        try self.traverse(node.body)
        self.scopes.pop()
    }

    public mutating func visit(_ node: SelectExpr) throws {
        // NOTE: Unfortunately, we can't bind the symbols of a select expression's ownee, because
        // it depends on the kind of declaration the owner's is refencing.
        if let owner = node.owner {
            try self.traverse(owner)
        }
    }

    public mutating func visit(_ node: Ident) throws {
        guard var definingScope = self.scopes.last.findScopeDefining(name: node.name) else {
            throw CompilerError.undefinedSymbol(name: node.name, location: node.location)
        }

        // If we're visiting the initial value of the identifier's declaration, we should bind it
        // to an enclosing scope.
        if self.underDeclaration[definingScope]?.contains(node.name) ?? false {
            guard let scope = definingScope.parent?.findScopeDefining(name: node.name) else {
                throw CompilerError.undefinedSymbol(name: node.name, location: node.location)
            }
            definingScope = scope
        }

        node.scope = definingScope
    }

    // MARK: Internals

    /// A stack of scopes.
    private var scopes: Stack<Scope> = [BuiltinScope()]

    /// Keeps track of what identifier is being declared while visiting its declaration.
    ///
    /// This mapping will help us keep track of what the identifier being declared when visiting
    /// its declaration, which is necessary to properly map the scopes of declaration expressions
    /// that refer to the same name as the identifier under declaration, but from an enclosing
    /// scope. For instance, consider the following snippet in which `x` declared within the
    /// function `f` hould be a new variable, but inialized with the value of the constant `x`
    /// defined in the global scope:
    ///
    ///     let x = 0
    ///     function f() { let x = x }
    ///
    private var underDeclaration: [Scope: Set<String>] = [:]

}
