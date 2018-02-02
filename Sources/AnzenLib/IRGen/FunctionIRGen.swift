import LLVM

extension IRGenerator {

    mutating func visit(_ node: FunDecl) throws {
        // Create the function prototype.
        let anzenType = node.type!.unqualified as! FunctionType
        let fn = self.builder.addFunction(
            node.name, type: anzenType.irFunctionType(in: self.llvmContext))

        // Create the function's entry point.
        let currentBlock = self.builder.insertBlock
        let entry = fn.appendBasicBlock(named: "entry", in: self.llvmContext)
        self.builder.positionAtEnd(of: entry)

        // Create the function's parameter allocations.
        var locals: [String: ValueBinding] = [:]
        var names = node.parameters.map { $0.name }
        if anzenType.codomain.unqualified !== BuiltinScope.AnzenNothing {
            names.append("__return__")
        }
        for (param, name) in zip(fn.parameters, names) {
            let binding = self.createEntryBlockAlloca(
                in: fn, named: param.name, typed: param.type, qualifiedBy: [.ref])
            let arg = ValueBinding(
                ref: param, qualifiers: [.ref], read: { param }, write: { _ in })
            try self.createRefStore(arg, to: binding)
            locals[name] = binding
        }

        // Create the function body.
        self.locals.push(locals)
        try self.visit(node.body)
        self.builder.buildRetVoid()
        self.functionVerifier.run(on: fn)
        self.locals.pop()

        if let block = currentBlock {
            self.builder.positionAtEnd(of: block)
        }
    }

    mutating func visit(_ node: ReturnStmt) throws {
        guard let returnPtr = self.locals.last["__return__"] else {
            fatalError("unexpected return value in procedure")
        }
        try self.visit(node.value!)
        try self.createCpyStore(self.stack.pop()!, to: returnPtr)
    }

    mutating func visit(_ node: CallExpr) throws {
        guard let calleeType = (node.callee as? TypedNode)?.type?.unqualified as? FunctionType
            else {
                fatalError("invalid callee type")
        }

        if let calleeIdentifier = node.callee as? Ident,
           let callee = self.module.function(named: calleeIdentifier.name)
        {
            let currentFn = self.builder.insertBlock!.parent!
            var args: [IRValue] = []

            for arg in node.arguments {
                try self.visit(arg.value)
                switch arg.bindingOp {
                case .cpy?:
                    // Pass-by-value semantics require explicit copies.
                    let cpy = self.createEntryBlockAlloca(
                        in: currentFn, named: "", typed: arg.type!)
                    try self.createCpyStore(self.stack.pop()!, to: cpy)
                    args.append(cpy.ref)

                default:
                    fatalError("unexpected passing semantics")
                }
            }

            let returnPtr: ValueBinding
            if calleeType.codomain.unqualified !== BuiltinScope.AnzenNothing {
                returnPtr = self.createEntryBlockAlloca(
                    in: currentFn, named: calleeIdentifier.name, typed: calleeType.codomain)
                args.append(returnPtr.ref)
            } else {
                let voidPtr = VoidType(in: self.llvmContext).constPointerNull()
                returnPtr = ValueBinding(
                    ref       : VoidType(in: self.llvmContext).constPointerNull(),
                    qualifiers: [],
                    read      : { voidPtr },
                    write     : { _ in })
            }

            _ = self.builder.buildCall(callee, args: args)
            stack.push(returnPtr)
            return
        }

        // TODO: Handle non-identifier callees.
        fatalError("unexpected callee node")
    }

    func createEntryBlockAlloca(
        in function    : Function,
        named name     : String,
        typed anzenType: QualifiedType) -> ValueBinding
    {
        let irType = anzenType.irType(in: self.llvmContext)!
        return self.createEntryBlockAlloca(
            in: function, named: name, typed: irType, qualifiedBy: anzenType.qualifiers)
    }

    func createEntryBlockAlloca(
        in function           : Function,
        named name            : String,
        typed irType          : IRType,
        qualifiedBy qualifiers: TypeQualifier) -> ValueBinding
    {
        let currentBlock = self.builder.insertBlock
        let entryBlock = function.entryBlock!
        if let firstInst = entryBlock.firstInstruction {
            builder.position(firstInst, block: entryBlock)
        }
        let alloca = builder.buildAlloca(type: irType, name: name)
        if let block = currentBlock {
            builder.positionAtEnd(of: block)
        }
        return ValueBinding(
            ref       : alloca,
            qualifiers: qualifiers,
            read      : { self.builder.buildLoad(alloca) },
            write     : { self.builder.buildStore($0, to: alloca) })
    }

}
