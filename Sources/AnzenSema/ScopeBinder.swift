import AnzenAST

public struct ScopeBinder: ASTVisitor, Pass {

    public let name: String = "scope binding"

    public init() {}

    public mutating func run(on module: ModuleDecl) -> [Error] {
        do {
            try self.visit(module)
            return self.errors
        } catch {
            return [error]
        }
    }

    public mutating func visit(_ node: ModuleDecl) throws {
        // NOTE: We choose to make all module scopes descend from Anzen's built-in scope. This
        // way, built-in symbols (e.g. `Int`) can be refered "as-is" within source code, yet we
        // don't loose the ability to shadow them.
        node.innerScope?.parent = self.scopes.last

        self.scopes.push(node.innerScope!)
        try self.visit(node.statements)
        self.scopes.pop()
    }

    public mutating func visit(_ node: Block) throws {
        self.scopes.push(node.innerScope!)
        try self.visit(node.statements)
        self.scopes.pop()
    }

    public mutating func visit(_ node: FunDecl) throws {
        // TODO: When we'll implement parameter default values, we'll also have to make sure that
        // the identifiers in the default value don't get bound to other parameters. For instance,
        // the following should throw an `UndefinedSymbol`:
        //
        //     fun f(x: Int = y, y: Int) {}
        //

        // Visit the function.
        self.scopes.push(node.innerScope!)
        try self.traverse(node)
        self.scopes.pop()
    }

    public mutating func visit(_ node: PropDecl) throws {
        self.underDeclaration[node.scope!] = node.name
        try self.traverse(node)
        self.underDeclaration.removeValue(forKey: node.scope!)
    }

    public mutating func visit(_ node: StructDecl) throws {
        self.scopes.push(node.innerScope!)
        try self.visit(node.body)
        self.scopes.pop()
    }

    public mutating func visit(_ node: SelectExpr) throws {
        // NOTE: Unfortunately, we can't bind the symbols of a select expression's ownee, because
        // it depends on the kind of declaration the owner's is refencing.
        if let owner = node.owner {
            try self.visit(owner)
        }
    }

    public mutating func visit(_ node: Ident) throws {
        // Find the scope that defines the visited identifier.
        guard let scope = self.scopes.last.findScopeDefining(name: node.name) else {
            self.errors.append(UndefinedSymbol(name: node.name, at: node.location))
            return
        }

        // If we're visiting the initial value of the identifier's declaration (e.g. as part of a
        // property declaration), we should bind it to an enclosing scope.
        if self.underDeclaration[scope] == node.name {
            guard let parentScope = scope.parent?.findScopeDefining(name: node.name) else {
                self.errors.append(UndefinedSymbol(name: node.name, at: node.location))
                return
            }
            node.scope = parentScope
        } else {
            node.scope = scope
        }

        // Visit the specializations.
        for specialization in node.specializations {
            try self.visit(specialization.value)
        }
    }

    /// A stack of scopes.
    private var scopes: Stack<Scope> = [Builtins.instance.scope]

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
    ///     fun f() { let x = x }
    ///
    private var underDeclaration: [Scope: String] = [:]

    private var errors: [Error] = []

}
