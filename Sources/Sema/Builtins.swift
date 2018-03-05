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

    // MARK: Builtin functions

    public let print    : FunctionType

    private init() {
        self.print = FunctionType(from: [(nil, self.Int.cst)], to: self.Int.cst)

        self.registerAlias(for: self.Anything)
        self.registerAlias(for: self.Nothing)
        self.registerAlias(for: self.Int)
        self.registerAlias(for: self.Double)
        self.registerAlias(for: self.Bool)
        self.registerAlias(for: self.String)

        self.scope.add(symbol: Symbol(name: "print", type: self.print))

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
    }

    private func registerAlias(for type: StructType) {
        self.scope.add(
            symbol: Symbol(
                name: type.name,
                type: TypeAlias(name: type.name, aliasing: type)))
    }

}
