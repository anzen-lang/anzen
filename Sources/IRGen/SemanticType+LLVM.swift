import AnzenTypes
import LLVM
import Sema

extension SemanticType {

    func llvmType(context: Context) -> IRType {
        let ty: IRType

        switch self {
        case Sema.Builtins.instance.Int:
            ty = IntType.int64
        case Sema.Builtins.instance.Double:
            ty = FloatType.fp128
        case Sema.Builtins.instance.Bool:
            ty = IntType.int1
        default:
            fatalError("Cannot emit LLVM type for \(self)")
        }

        return ty*
    }

}

postfix operator *
postfix func * (pointee: IRType) -> IRType {
    return PointerType(pointee: pointee)
}
