import AnzenAST
import AnzenSema
import IO

/// Parses the input and produces an AST without any type annotation.
public func parse(text: String) throws -> ModuleDecl {
    return try Grammar.module.parse(text)
}

public func performSema(on module: ModuleDecl) -> [Error] {
    var passes: [Pass] = [
        SymbolsExtractor(),
        ScopeBinder(),
        ConstraintSolver(),
    ]

    var errors: [Error] = []
    for i in 0 ..< passes.count {
        errors.append(contentsOf: passes[i].run(on: module))
    }
    return errors
}
