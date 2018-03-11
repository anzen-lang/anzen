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
        let fn = builder.addFunction(name, type: builder.buildFunctionType(of: ty))

        // Setup function attributes.
        fn.addAttribute(.nounwind, to: .function)
        if !ty.codomain.type.equals(to: Builtins.instance.Nothing) {
            fn.addAttribute(.sret, to: .argument(0))
            fn.addAttribute(.noalias, to: .argument(0))
        }

        // Create the entry point of the function.
        let entry = fn.appendBasicBlock(named: "entry", in: context)
        let currentBlock = builder.insertBlock
        builder.positionAtEnd(of: entry)

        var local: [String: Emittable] = [:]

        // Unless the function's codomain is `Nothing`, allocate the inout return value.
        var parameters = fn.parameters
        if !ty.codomain.type.equals(to: Builtins.instance.Nothing) {
            let rvPointer = parameters.removeFirst()
            let rv = LocalProperty(in: fn, anzenType: ty.codomain.type, builder: builder)
            rv.managedValue = ManagedValue(
                anzenType: rv.anzenType, llvmType: rv.llvmType, builder: builder,
                alloca: rvPointer)
            builder.buildStore(rvPointer, to: rv.alloca)
            local["__rv"] = rv
        }

        // Allocate the function's parameters.
        for (param, decl) in zip(parameters, node.parameters) {
            let prop = LocalProperty(in: fn, anzenType: decl.type!, builder: builder)
            builder.buildStore(param, to: prop.alloca)
            locals.top![param.name] = prop
        }

        // Allocate the function's closure.
        let closure = builder.buildEntryAlloca(in: fn, type: IntType.int8*)
        builder.buildStore(parameters.last!, to: closure)

        // Emit the body of the function.
        locals.push(local)
        try visit(node.body)
        locals.pop()
        builder.buildRetVoid()
        passManager.run(on: fn)

        // Reset the insertion point.
        if currentBlock != nil {
            builder.positionAtEnd(of: currentBlock!)
        } else {
            builder.clearInsertionPosition()
        }
    }

    public mutating func visit(_ node: ReturnStmt) throws {
        let rv = locals.top?["__rv"] as! LocalProperty
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
