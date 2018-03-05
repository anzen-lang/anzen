import AnzenAST
import LLVM
import Sema

extension IRGenerator {

    public mutating func visit(_ node: CallExpr) throws {
        // Create the format string.
        let format = self.builder.buildGlobalStringPtr("%ld", name: "str")

        // Generate the IR for the argument's value.
        try self.visit(node.arguments[0])
        let value = self.stack.pop()!

        // Generate the IR for the function call.
        // Note that we discard the result of calling `printf`.
        _ = self.builder.buildCall(self.printf, args: [format, value.val])
    }

    public mutating func visit(_ node: CallArg) throws {
        try self.visit(node.value)
    }

}
