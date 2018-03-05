import AnzenAST
import LLVM

extension IRGenerator {

    public mutating func visit(_ node: Literal<Int>) throws {
        self.stack.push((IntType.int64.constant(node.value), .value))
    }

}

