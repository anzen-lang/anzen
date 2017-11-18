import LLVM

extension QualifiedType {

    func irType(context: Context) -> IRType? {
        var baseType: IRType? = nil

        switch self.unqualified {
        case let structType as StructType:
            switch structType {
            case BuiltinScope.AnzenInt : baseType = IntType.int64
            case BuiltinScope.AnzenBool: baseType = IntType.int1
            default:
                break
            }

        default:
            break
        }

        if let baseType = baseType {
            return self.qualifiers.contains(.ref)
                ? PointerType(pointee: baseType)
                : baseType
        }
        return nil
    }

}
