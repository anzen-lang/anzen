import AnzenAST
import AnzenTypes
import LLVM
import Sema

extension UnmanagedValue {

    static func literal(_ value: Int) -> UnmanagedValue {
        return UnmanagedValue(
            anzenType: Builtins.instance.Int,
            llvmType : IntType.int64,
            val      : IntType.int64.constant(value))
    }

}

extension IRGenerator {

    public mutating func visit(_ node: Literal<Int>) throws {
        stack.push(UnmanagedValue.literal(node.value))
    }

}
