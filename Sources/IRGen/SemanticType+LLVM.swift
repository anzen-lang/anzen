import AnzenTypes
import LLVM
import Sema

extension IRGenerator {

    func buildType(of anzenType: AnzenTypes.SemanticType) -> IRType {
        switch anzenType {
        case Sema.Builtins.instance.Int:
            return IntType.int64
        case Sema.Builtins.instance.Double:
            return FloatType.fp128
        case Sema.Builtins.instance.Bool:
            return IntType.int1

        case let ty as AnzenTypes.FunctionType:
            return self.buildType(of: ty)

        default:
            fatalError("Cannot emit LLVM type for \(self)")
        }
    }

    func buildType(of anzenType: AnzenTypes.FunctionType) -> LLVM.FunctionType {
        return LLVM.FunctionType(
            argTypes: anzenType.domain.map({ _ in self.runtime.gc_object }),
            returnType: runtime.gc_object)
    }

}

postfix operator *
postfix func * (pointee: IRType) -> IRType {
    return PointerType(pointee: pointee)
}
