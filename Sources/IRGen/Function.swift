import AnzenAST
import AnzenTypes
import LLVM
import Sema

class CallResult: Emittable {

    init(anzenType: SemanticType, builder: IRBuilder) {
        self.anzenType = anzenType
        self.llvmType = builder.buildValueType(of: anzenType)
        self.managedValue = .allocate(anzenType: anzenType, builder: builder)
    }

    /// The Anzen semantic type of the call result.
    let anzenType: SemanticType

    /// The LLVM IR type of the call result.
    let llvmType: IRType

    /// The managed value bounded to the call result.
    var managedValue: ManagedValue

    /// The LLVM IR value representing the call result.
    var val: IRValue {
        return managedValue.val
    }

}

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
            prop.managedValue = ManagedValue(
                anzenType: prop.anzenType, llvmType: prop.llvmType, builder: builder,
                alloca: param)
            builder.buildStore(param, to: prop.alloca)
            local[decl.name] = prop
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
        // FIXME: For now, we simply treat calls to `print` as special cases. But we won't have to
        // anymore when we'll implement C-link functions.
        if let callee = node.callee as? Ident, callee.name == "print" {
            // Create the format string.
            let format = builder.buildGlobalStringPtr("%ld\n", name: "str")

            // Generate the IR for the argument's value.
            try visit(node.arguments[0])
            let value = stack.pop()!

            // Generate the IR for the function call.
            // Note that we discard the result of calling `printf`.
            _ = builder.buildCall(printf, args: [format, value.val])
            return
        }

        // Allocate memory for the function's return value, if any.
        var argsVal: [IRValue] = []
        var returnVal: CallResult? = nil
        if !node.type!.equals(to: Builtins.instance.Nothing) {
            returnVal = CallResult(anzenType: node.type!, builder: builder)
            argsVal.append(returnVal!.managedValue.alloca)
        }

        // Generate the IR for the arguments.
        let args = try node.arguments.map { callArg -> Emittable in
            try visit(callArg)
            return stack.pop()!
        }
        argsVal.append(contentsOf: args.map { ($0 as? LocalProperty)!.managedValue!.alloca })

        // FIXME: Create capture objects.
        argsVal.append(IntType.int8*.null())

        // Generate the IR for the function call.
        guard let calleeIdent = node.callee as? Ident else {
            fatalError("FIXME: implement non-ident callees")
        }
        let calleeName = Mangler.mangle(symbol: calleeIdent.symbol!)
        guard let calleeFn = module.function(named: calleeName) else {
            fatalError("undefined function: '\(calleeName)'")
        }
        _ = builder.buildCall(calleeFn, args: argsVal)
        if returnVal != nil {
            stack.push(returnVal!)
        }

        // Release all call arguments.
        for arg in args {
            (arg as? LocalProperty)?.managedValue?.release()
        }
    }

    public mutating func visit(_ node: CallArg) throws {
        guard let currentFn = builder.insertBlock?.parent else {
            fatalError("FIXME: allocate global result")
        }

        try visit(node.value)
        let val = stack.pop()!
        let arg = LocalProperty(in: currentFn, anzenType: node.type!, builder: builder)

        switch node.bindingOp {
        case .none, .cpy?: arg.bindByCopy(to: val)
        case .ref?       : arg.bindByReference(to: val)
        case .mov?       : arg.bindByMove(to: val)
        default:
            fatalError("unexpected binding operator")
        }

        (val as? CallResult)?.managedValue.release()

        stack.push(arg)
    }

}
