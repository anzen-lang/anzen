import AnzenAST
import AnzenTypes

/// A visitor that extracts the symbols declared in the AST's scopes.
///
/// This visitor annotates scope-opening nodes with symbols for each entity (e.g. function, type,
/// ...) that's declared within said scope. It also annotations declaration nodes with their
/// corresponding scope.
///
/// This step is indispensable for lexical scoping (perfomed by the `ScopeBinder`). It's what's
/// let us bind identifiers to the appropriate declaration (i.e. to the appropriate scope).
public struct SymbolsExtractor: ASTVisitor {

    public init() {}

    public mutating func visit(_ node: ModuleDecl) throws {
        // Create a new scope for the module.
        node.innerScope = Scope()

        // Visit the module's statements.
        self.stack.push(node)
        try self.visit(node.statements)
        self.stack.pop()
    }

    public mutating func visit(_ node: Block) throws {
        // Create a new scope for the block.
        node.innerScope = Scope(parent: self.stack.last.innerScope)

        // Visit the block's statements.
        self.stack.push(node)
        try self.visit(node.statements)
        self.stack.pop()
    }

    public mutating func visit(_ node: FunDecl) throws {
        // If there already are symbols with the same name in the current scope, make sure they
        // all are overloadable (i.e. they correspond to other function declarations).
        let symbols = self.stack.last.innerScope![node.name]
        guard symbols.forAll({ $0.isOverloadable }) else {
            throw DuplicateDeclarationError(name: node.name, location: node.location)
        }

        // Create a symbol for the function's name within the currently visited scope.
        let functionSymbol = Symbol(
            name: node.name, overloadable: true, generic: !node.placeholders.isEmpty)
        self.stack.last.innerScope!.add(symbol: functionSymbol)
        node.scope  = self.stack.last.innerScope
        node.symbol = functionSymbol

        // Create a new scope for the function's parameters and generic placeholders.
        node.innerScope = Scope(name: node.name, parent: self.stack.last.innerScope)
        self.stack.push(node)
        for placeholder in node.placeholders {
            // Catch duplicate placeholder declarations.
            guard !node.innerScope!.defines(name: placeholder) else {
                throw DuplicateDeclarationError(name: placeholder, location: node.location)
            }
            node.innerScope!.add(
                symbol: Symbol(
                    name: placeholder,
                    type: TypeAlias(name: placeholder, aliasing: TypeVariable())))
        }

        // Note that parameters aren't bound to the same scope as that of the function's body,
        // so that they may be shadowed:
        //
        //     fun f(x: Int) { let x = x }
        //
        try self.visit(node.parameters)

        // Visit the function's body.
        try self.visit(node.body)
        self.stack.pop()
    }

    public mutating func visit(_ node: ParamDecl) throws {
        // Make sure the parameter's name wasn't already declared.
        guard !self.stack.last.innerScope!.defines(name: node.name) else {
            throw DuplicateDeclarationError(name: node.name, location: node.location)
        }

        // Create a new symbol for the parameter, and visit the node's declaration.
        self.stack.last.innerScope!.add(symbol: Symbol(name: node.name))
        node.scope = self.stack.last.innerScope
        try self.traverse(node)
    }

    public mutating func visit(_ node: PropDecl) throws {
        // Make sure the property's name wasn't already declared.
        guard !self.stack.last.innerScope!.defines(name: node.name) else {
            throw DuplicateDeclarationError(name: node.name, location: node.location)
        }

        // Create a new symbol for the property, and visit the node's declaration.
        self.stack.last.innerScope!.add(symbol: Symbol(name: node.name))
        node.scope = self.stack.last.innerScope
        try self.traverse(node)
    }

    public mutating func visit(_ node: StructDecl) throws {
        // Make sure the struct's name wasn't already declared.
        guard !self.stack.last.innerScope!.defines(name: node.name) else {
            throw DuplicateDeclarationError(name: node.name, location: node.location)
        }

        // Create a type alias for the node's symbol.
        let alias = TypeAlias(name: node.name, aliasing: TypeVariable())
        let structSymbol = Symbol(
            name: node.name, type: alias, generic: !node.placeholders.isEmpty)
        self.stack.last.innerScope!.add(symbol: structSymbol)
        node.scope = self.stack.last.innerScope
        node.type  = alias

        // Create a new scope for the struct's generic placeholders.
        node.innerScope = Scope(name: node.name, parent: self.stack.last.innerScope)
        self.stack.push(node)
        for placeholder in node.placeholders {
            // Catch duplicate placeholder declarations.
            guard !node.innerScope!.defines(name: placeholder) else {
                throw DuplicateDeclarationError(name: placeholder, location: node.location)
            }
            node.innerScope!.add(
                symbol: Symbol(
                    name: placeholder,
                    type: TypeAlias(name: placeholder, aliasing: TypeVariable())))
        }

        // Introduce a `Self` symbol in the type's scope, to handle the `Self` placeholder.
        node.innerScope!.add(symbol: Symbol(name: "Self", type: alias))

        // Visit the struct's members.
        try self.traverse(node)
        self.stack.pop()
    }

    // MARK: Internals

    var stack: Stack<ScopeNode> = []

}
