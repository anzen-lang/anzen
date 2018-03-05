import AnzenAST
import LLVM
import Sema

extension IRGenerator {

    public mutating func visit(_ node: CallExpr) throws {
        // Create the format string.
        let format = self.builder.buildGlobalStringPtr("%ld", name: "str")

        // Generate the IR for the argument's value.
        try self.visit(node.arguments[0])
        var (value, storage) = self.stack.pop()!
        if storage == .reference {
            value = self.builder.buildLoad(value)
        }

        // Generate the IR for the function call.
        let rv = self.builder.buildCall(self.printf, args: [format, value])
        self.stack.push((rv, .value))
    }

    public mutating func visit(_ node: CallArg) throws {
        try self.visit(node.value)
    }

}

