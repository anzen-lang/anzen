import AnzenAST

/// Parses the input and produces an AST without any type annotation.
public func parse(text: String) throws -> ModuleDecl {
    return try Grammar.module.parse(text)
}

// /// Type-checks an AST.
// public func performSema(on module: ModuleDecl) throws -> ModuleDecl {
//     // Annotate each scope-opening node with the symbols it declares.
//     var symbolsExtractor = SymbolsExtractor()
//     symbolsExtractor.visit(module)
//
//     // Bind all symbols of the module to their respective scope.
//     var scopeBinder = ScopeBinder()
//     try scopeBinder.visit(module)
//
//     // Infer the types of declarations and expressions.
//     try inferTypes(module)
//
//     print(String(reflecting: module))
//
//     // Generate the LLVM IR of the module.
//     var irGenerator = IRGenerator(moduleName: "__main__", asEntryPoint: true)
//     try irGenerator.visit(module)
//     irGenerator.finalize()
//     irGenerator.module.dump()
//
//     return module
// }
