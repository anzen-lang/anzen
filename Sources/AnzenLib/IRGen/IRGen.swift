import LLVM

struct IRGenerator: ASTVisitor {

    init(moduleName: String, asEntryPoint: Bool = false) {
        self.llvmContext = Context.global
        self.module      = Module(name: moduleName, context: self.llvmContext)
        self.builder     = IRBuilder(module: self.module)

        // FIXME: Add relevant optimization passes.
        self.functionVerifier = FunctionPassManager(module: self.module)

        // If the module's the entry point, we implicitly enclose it in a "main" function.
        if asEntryPoint {
            let fn = self.builder.addFunction(
                "main", type: LLVM.FunctionType(argTypes: [], returnType: IntType.int32))
            let entry = fn.appendBasicBlock(named: "entry", in: self.llvmContext)
            self.builder.positionAtEnd(of: entry)
            self.locals.push([:])
        }
    }

    func finalize() {
        if let fn = self.module.function(named: "main") {
            self.builder.positionAtEnd(of: fn.lastBlock!)
            self.builder.buildRet(IntType.int32.constant(0))
            self.functionVerifier.run(on: fn)
        }
    }

    mutating func visit(_ node: PropDecl) throws {
        if let insertBlock = self.builder.insertBlock {
            // Get the LLVM function under declaration.
            let fn = insertBlock.parent!

            // Create an alloca for the local variable, and store it as a local symbol table.
            let property = self.createEntryBlockAlloca(
                in: fn, named: node.name, typed: node.type!)
            self.locals.last[node.name] = property

            if let (op, value) = node.initialBinding {
                try self.createBinding(to: property, op: op, rvalue: value as! TypedNode)
            }
        }
//        // Create a global variable.
//        var property = self.builder.addGlobal(
//            node.name, type: node.type!.irType(context: self.llvmContext)!)
//        property.linkage = .common
//        property.initializer = initialValue
//        self.globals[node.name] = property
    }

    mutating func visit(_ node: Literal<Int>) throws {
        self.stack.push(IntType.int64.constant(node.value))
    }

    /// The LLVM module currently being generated.
    let module : Module

    /// The LLVM builder that will build instructions.
    let builder: IRBuilder

    /// The LLVM context the module lives in.
    let llvmContext: Context

    /// A stack that lets us accumulate the LLVM values of expressions, before they are consumed
    /// by a statement.
    ///
    /// - Note: The stack should be emptied every time after the IR of a particular statement has
    ///   been generated.
    var stack: Stack<IRValue> = []

    /// A stack of maps of local symbols.
    var locals: Stack<[String: PropertyBinding]> = []

    /// A map of global symbols.
    var globals: [String: IRGlobal] = [:]

    /// LLVM sanity checker.
    let functionVerifier: FunctionPassManager

    // MARK: Internals

    func createEntryBlockAlloca(
        in function    : Function,
        named name     : String,
        typed anzenType: QualifiedType) -> PropertyBinding
    {
        let irType = anzenType.irType(context: self.llvmContext)!
        let currentBlock = self.builder.insertBlock
        let entryBlock = function.entryBlock!
        if let firstInst = entryBlock.firstInstruction {
            builder.position(firstInst, block: entryBlock)
        }
        let alloca = builder.buildAlloca(type: irType, name: name)
        if let block = currentBlock {
            builder.positionAtEnd(of: block)
        }
        return PropertyBinding(
            ref       : alloca,
            qualifiers: anzenType.qualifiers,
            read      : { self.builder.buildLoad(alloca) },
            write     : { self.builder.buildStore($0, to: alloca) })
    }

    mutating func createBinding(
        to dest: PropertyBinding, op: Operator, rvalue: TypedNode) throws
    {
        switch op {
        case .cpy:
            // Dereference the lvalue if needed.
            let ptr = dest.qualifiers.contains(.ref)
                ? self.builder.buildLoad(dest.ref)
                : dest.ref
//                ? self.builder.buildLoad(dest.read())
//                : dest.read()

            // Generate the rvalue and dereference it if needed.
            try self.visit(rvalue)
            let val = rvalue.type!.qualifiers.contains(.ref)
                ? self.builder.buildLoad(self.stack.pop()!)
                : self.stack.pop()!

            self.builder.buildStore(val, to: ptr)

        default:
            break
        }
    }

}

struct PropertyBinding {

    let ref       : IRValue
    let qualifiers: TypeQualifier
    let read      : () -> IRValue
    let write     : (IRValue) -> Void

}
