import AnzenAST
import AnzenTypes
import LLVM
import Sema

extension UnmanagedValue {

    /// Creates an unmanaged value from an integer literal.
    static func literal(_ value: Int) -> UnmanagedValue {
        return UnmanagedValue(
            anzenType: Builtins.instance.Int,
            llvmType: NativeInt,
            val: NativeInt.constant(value))
    }

}

extension IRGenerator {

    /// Emits the IR of a literal.
    public mutating func visit(_ node: Literal<Int>) throws {
        stack.push(UnmanagedValue.literal(node.value))
    }

}
