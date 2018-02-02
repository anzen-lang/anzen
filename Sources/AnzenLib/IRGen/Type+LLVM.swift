import LLVM

extension QualifiedType {

    func irType(in context: Context) -> IRType? {
        var baseType: IRType? = nil

        switch self.unqualified {
        case let functionType as FunctionType:
            baseType = functionType.irFunctionType(in: context)

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

extension FunctionType {

    func irFunctionType(in context: Context) -> LLVM.FunctionType {
        var params = self.domain.map { param in
            // Anzen function parameters are always emitted as references, even if they were
            // declared as @val types, so that we can handle move passing semantics.
            return param.type.qualifiers.contains(.ref)
                ? param.type.irType(in: context)!
                : PointerType(pointee: param.type.irType(in: context)!)
        }

        // As function return values are expected to be allocated on the call site, we've to
        // add a parameter typed with a reference on the codomain.
        if self.codomain.unqualified !== BuiltinScope.AnzenNothing {
            let returnType = self.codomain.qualifiers.contains(.ref)
                ? self.codomain.irType(in: context)!
                : PointerType(pointee: self.codomain.irType(in: context)!)
            params.append(returnType)
        }

        // TODO: Handle capture lists.

        return LLVM.FunctionType(
            argTypes  : params,
            returnType: VoidType(in: context))
    }

}
