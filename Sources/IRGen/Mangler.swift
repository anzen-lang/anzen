import AnzenAST
import AnzenTypes
import Sema

/// Name mangler.
struct Mangler {

    /// Mangles a symbol according to its scope and type.
    static func mangle(symbol: Symbol) -> String {
        // All mangled symbols start with `_Z`
        var result = "_Z"

        // Mangle the scope (i.e. namespace) of the symbol.
        var namespace = ""
        var scope = symbol.scope
        repeat {
            // Keep only named scopes.
            if let name = scope?.name {
                namespace = String(name.count) + name + namespace
            }
            scope = scope?.parent
        } while (scope != nil) && (scope != Builtins.instance.scope)
        result += namespace

        // Mangle the name of the symbol.
        result += String(symbol.name.count) + symbol.name

        // Mangle the type of the symbol.
        result += Mangler.mangle(type: symbol.type)

        // FIXME: Handle generic symbols.

        return result
    }

    /// Mangles a semantic type.
    static func mangle(type: SemanticType) -> String {
        switch type {
        case Builtins.instance.Anything : return "a"
        case Builtins.instance.Nothing  : return "n"
        case Builtins.instance.Int      : return "i"
        case Builtins.instance.Double   : return "d"
        case Builtins.instance.Bool     : return "b"
        case Builtins.instance.String   : return "s"

        case let ty as StructType       : return Mangler.mangle(type: ty)
        case let ty as FunctionType     : return Mangler.mangle(type: ty)

        default:
            fatalError("unexpected type")
        }
    }

    /// Mangles a struct type.
    static func mangle(type: StructType) -> String {
        return "S" + String(type.name.count) + type.name
    }

    /// Mangles a function type.
    static func mangle(type: FunctionType) -> String {
        var result = "F"
        for param in type.domain {
            if let label = param.label {
                result += String(label.count) + label
            } else {
                result += "_"
            }
            result += Mangler.mangle(qualified: param.type)
        }
        return result + "__" + Mangler.mangle(qualified: type.codomain)
    }

    /// Mangles a qualified type.
    static func mangle(qualified: QualifiedType) -> String {
        var result = ""
        if qualified.qualifiers.contains(.cst) {
            result += "c"
        }
        if qualified.qualifiers.contains(.mut) {
            result += "m"
        }
        return result + Mangler.mangle(type: qualified.type)
    }

}
