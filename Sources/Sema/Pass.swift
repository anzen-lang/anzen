import AnzenAST

public protocol Pass {

    mutating func run(on module: ModuleDecl) -> [Error]

    var name: String { get }

}
