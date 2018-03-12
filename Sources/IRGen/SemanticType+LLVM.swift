import AnzenTypes
import LLVM
import Sema

extension IRBuilder {

    /// Builds the LLVM value type equivalent to the given Anzen semantic type.
    ///
    /// This method creates the LLVM type of the values that are manipulated at the IR level. By
    /// default, all anzen values represent garbage collected references, so their IR type gets
    /// lowered as a structure containing with with one additional field to hold a reference
    /// counter (note that Anzen's garbage collection is based on reference counting), plus one
    /// more field for the value's metadata (e.g. runtime type information) and its virtual table.
    ///
    /// The raw type, i.e. the actual LLVM type of the value being manipulated, can be obtained
    /// by setting `raw` to `true`. Note however that this won't apply recursively!
    ///
    /// - Note: LLVM function types are not first class values, but function pointers can be
    ///   manipulated like any other first-class value. Hence, building the raw type of a function
    ///   type with this method creates a pointer to function type.
    func buildValueType(of anzenType: AnzenTypes.SemanticType, raw: Bool = false) -> IRType {
        let rawType: IRType

        switch anzenType {
        case Sema.Builtins.instance.Int:
            rawType = IntType.int64
        case Sema.Builtins.instance.Double:
            rawType = FloatType.fp128
        case Sema.Builtins.instance.Bool:
            rawType = IntType.int1

        case let ty as AnzenTypes.FunctionType:
            rawType = buildFunctionType(of: ty)*

        default:
            fatalError("Cannot emit LLVM type for \(self)")
        }

        return raw
            ? rawType
            : LLVM.StructType(elementTypes: [NativeInt, IntType.int8*, rawType])
    }

    /// Builds the LLVM function type equivalent to the given Anzen function type.
    ///
    /// Function closures are passed as the first argument, in the form of an array of pointers.
    /// Because copies should always be explicit, all values exchanged between a caller and its
    /// callee are exchanged by reference (i.e. pointer) at the LLVM level, including the return
    /// value of the function.
    ///
    /// - TODO: Implement type creation of functions with C linkage.
    func buildFunctionType(of anzenType: AnzenTypes.FunctionType) -> LLVM.FunctionType {
        // Create the "regular" argument types.
        var argTypes = anzenType.domain.map { buildValueType(of: $0.type.type)* }

        // Prepend the return type unless it's `Nothing`.
        if !anzenType.codomain.type.equals(to: Builtins.instance.Nothing) {
            let llvmCodomain = buildValueType(of: anzenType.codomain.type)*
            argTypes.insert(llvmCodomain, at: 0)
        }

        // Append the closure type.
        argTypes.append(IntType.int8*)

        // Create and return the LLVM function type.
        return LLVM.FunctionType(argTypes: argTypes, returnType: VoidType())
    }

}

postfix operator *
postfix func * (pointee: IRType) -> IRType {
    return PointerType(pointee: pointee)
}
