import AnzenAST
import AnzenTypes
import LLVM
import Sema

extension IRGenerator {

    /// Declares a local or global property in the current context.
    public mutating func visit(_ node: PropDecl) throws {
        if let fn = builder.insertBlock?.parent {
            // Create the local property
            let prop = LocalProperty(in: fn, anzenType: node.type!, builder: builder)
            symbolMaps.top![node.symbol!] = prop

            // Generate the IR for optional the initial value.
            if let (op, value) = node.initialBinding {
                try visit(value)
                prop.bind(to: stack.pop()!, by: op)
            }
        } else {
            fatalError("global variables aren't supported yet")
        }
    }

    /// Emits the IR of a function's body in the current context.
    public mutating func visit(_ node: FunDecl) throws {
        // Retrieve the function object
        let fnName = Mangler.mangle(symbol: node.symbol!)
        guard let fn = llvmModule.function(named: fnName) else {
            fatalError("\(fnName) is not declared")
        }
        guard let fnTy = node.type! as? AnzenTypes.FunctionType else {
            fatalError("\(node.name) doesn't have a function type")
        }

        // Create the entry point of the function.
        let entry = fn.appendBasicBlock(named: "entry", in: context)
        let currentBlock = builder.insertBlock
        builder.positionAtEnd(of: entry)

        // Allocate the function parameters.
        var params = fn.parameters

        // Unless the function's codomain is `Nothing`, allocate the inout return value.
        if !fnTy.codomain.type.equals(to: Builtins.instance.Nothing) {
            let alloca = params.removeFirst()
            let rv = LocalProperty(in: fn, anzenType: fnTy.codomain.type, builder: builder)
            rv.managedValue = ManagedValue(
                anzenType: rv.anzenType, llvmType: rv.llvmType,
                builder: builder, alloca: alloca)
            returnProps.push(rv)
        }

        // Allocate the function's parameters.
        symbolMaps.push([:])
        for (alloca, decl) in zip(params, node.parameters) {
            let prop = LocalProperty(in: fn, anzenType: decl.type!, builder: builder)
            prop.managedValue = ManagedValue(
                anzenType: prop.anzenType, llvmType: prop.llvmType,
                builder: builder, alloca: alloca)
            symbolMaps.top![decl.symbol!] = prop
        }

        // Allocate the function's closure.
        let closure = builder.buildEntryAlloca(in: fn, type: IntType.int8*)
        builder.buildStore(params.last!, to: closure)

        // Emit the body of the function.
        try visit(node.body)
        builder.buildRetVoid()
        passManager.run(on: fn)

        // Clean the symbol map and return register.
        symbolMaps.pop()
        if !fnTy.codomain.type.equals(to: Builtins.instance.Nothing) {
            returnProps.pop()
        }

        // Reset the insertion point.
        if currentBlock != nil {
            builder.positionAtEnd(of: currentBlock!)
        } else {
            builder.clearInsertionPosition()
        }
    }

}
