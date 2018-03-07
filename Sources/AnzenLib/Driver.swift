import AnzenAST
import IRGen
import LLVM
import Sema
import Utils

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

public func generateLLVM(of module: ModuleDecl, withOptimizations: Bool = false) -> Module {
    var generator = IRGenerator(moduleName: "main", withOptimizations: withOptimizations)
    return generator.transform(module, asEntryPoint: true)
}
