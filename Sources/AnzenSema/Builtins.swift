import AnzenAST
import AnzenTypes

public class Builtins {

    public static let instance = Builtins()

    // MARK: Bultin scope

    public let scope = Scope(name: "Anzen")

    // MARK: Builtin types

    public let Anything = StructType(name: "Anything")
    public let Nothing  = StructType(name: "Nothing")
    public let Int      = StructType(name: "Int")
    public let Double   = StructType(name: "Double")
    public let Bool     = StructType(name: "Bool")
    public let String   = StructType(name: "String")

    private init() {
        self.Int.methods["+"] = [
            FunctionType(
                from: [(label: nil, type: self.Int.qualified(by: .cst))],
                to  : self.Int.qualified(by: .cst)),
        ]
        self.Int.methods["-"] = [
            FunctionType(
                from: [(label: nil, type: self.Int.qualified(by: .cst))],
                to  : self.Int.qualified(by: .cst)),
        ]

        self.addSymbol(for: self.Anything)
        self.addSymbol(for: self.Nothing)
        self.addSymbol(for: self.Int)
        self.addSymbol(for: self.Double)
        self.addSymbol(for: self.Bool)
        self.addSymbol(for: self.String)
    }

    private func addSymbol(for type: StructType) {
        self.scope.add(
            symbol: Symbol(
                name: type.name,
                type: TypeAlias(name: type.name, aliasing: type)))
    }

}
