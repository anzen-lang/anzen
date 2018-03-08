import AnzenAST
import AnzenTypes
import LLVM
import Sema

extension IRGenerator {

    public mutating func visit(_ node: FunDecl) throws {
        // Create the function object.
        guard let ty = node.type! as? AnzenTypes.FunctionType else {
            fatalError("\(node.name) doesn't have a function type")
        }
        let name = Mangler.mangle(symbol: node.symbol!)
        let fn = builder.addFunction(name, type: buildType(of: ty))

        // Create the entry point of the function.
        let entry = fn.appendBasicBlock(named: "entry", in: context)
        let currentBlock = builder.insertBlock
        builder.positionAtEnd(of: entry)

        // Create an alloca for the return value of the function, and store its parameters in its
        // local symbol table.
        let rv = LocalProperty(in: fn, type: ty.codomain.type, generator: self)
        locals.push(["__rv__": rv])
        for (param, decl) in zip(fn.parameters, node.parameters) {
            let prop = LocalProperty(in: fn, type: decl.type!, generator: self, name: decl.name)
            builder.buildStore(param, to: prop.pointer)
            locals.top![param.name] = prop
        }

        // Emit the body of the function.
        try visit(node.body)
        builder.buildRet(builder.buildLoad(rv.pointer))
        locals.pop()

        // Reset the insertion point.
        if currentBlock != nil {
            builder.positionAtEnd(of: currentBlock!)
        } else {
            builder.clearInsertionPosition()
        }
    }

    public mutating func visit(_ node: ReturnStmt) throws {
        let rv = (locals.top?["__rv__"] as? LocalProperty)!
        try buildBinding(to: rv, op: .cpy, valueOf: node.value!)
    }

    public mutating func visit(_ node: CallExpr) throws {
        // Create the format string.
        let format = builder.buildGlobalStringPtr("%ld", name: "str")

        // Generate the IR for the argument's value.
        try visit(node.arguments[0])
        let value = stack.pop()!

        // Generate the IR for the function call.
        // Note that we discard the result of calling `printf`.
        _ = self.builder.buildCall(self.printf, args: [format, value.val])
    }

    public mutating func visit(_ node: CallArg) throws {
        try self.visit(node.value)
    }

}
