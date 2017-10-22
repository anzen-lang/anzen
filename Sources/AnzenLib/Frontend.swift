
/// Parses the input and produces an AST without any type annotation.
public func parse(text: String) throws -> Module {
    return try Grammar.module.parse(text)
}

/// Type-checks an AST.
public func performSema(on module: Module) throws -> Module {
    // Annotate each scope-opening node with the symbols it declares.
    var symbolsExtractor = SymbolsExtractor()
    symbolsExtractor.visit(module)

    print(String(reflecting: module))

    return module
}
