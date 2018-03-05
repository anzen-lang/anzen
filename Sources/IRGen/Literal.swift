import AnzenAST
import AnzenTypes
import LLVM
import Sema

extension StackValue {

    static func literal(_ value: Int) -> StackValue {
        return StackValue(
            anzenType: Builtins.instance.Int,
            llvmType : IntType.int64,
            val      : IntType.int64.constant(value))
    }

}

extension IRGenerator {

    public mutating func visit(_ node: Literal<Int>) throws {
        self.stack.push(StackValue.literal(node.value))
    }

}
