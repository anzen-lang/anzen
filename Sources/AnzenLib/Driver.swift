import AnzenAST
import AnzenSema

/// Parses the input and produces an AST without any type annotation.
public func parse(text: String) throws -> ModuleDecl {
    return try Grammar.module.parse(text)
}

public func performSema(on module: ModuleDecl) throws {
    var pass: ASTVisitor

    // This pass associates scope-opening nodes (e.g. Block, FunDecl, ...) with scope instances,
    // and identify the symbols that are declared within those scopes.
    pass = SymbolsExtractor()
    try pass.visit(module)

    // This pass binds value and type identifiers to the scope where they are declared.
    pass = ScopeBinder()
    try pass.visit(module)

    // This pass builds the type of named types and functions.
    // pass = TypeCreator()
    // try pass.visit(module)

    // This pass infers the type of the nodes of the AST.
    var constraintExtractor = ConstraintExtractor()
    try constraintExtractor.visit(module)

    let constraintSystem = ConstraintSystem(constraints: constraintExtractor.constraints)
    if let solution = try constraintSystem.next() {
        for (variable, type) in solution {
            print("\(variable) => \(type)")
        }
    }
}
