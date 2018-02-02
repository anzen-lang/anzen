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

    mutating func visit(_ node: Ident) throws {
        guard let binding = self.locals.last[node.name] else {
            fatalError("undefined identifier '\(node.name)'")
        }
        self.stack.push(binding)
    }

    mutating func visit(_ node: Literal<Int>) throws {
        self.stack.push(ValueBinding(
            ref       : IntType.int64.constant(node.value),
            qualifiers: node.type!.qualifiers,
            read      : { return IntType.int64.constant(node.value) },
            write     : { _ in fatalError("cannot write into a constant") }))
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
    var stack: Stack<ValueBinding> = []

    /// A stack of maps of local symbols.
    var locals: Stack<[String: ValueBinding]> = []

    /// LLVM sanity checker.
    let functionVerifier: FunctionPassManager

}

/// Represents the binding of some value to some memory location.
struct ValueBinding {

    /// A pointer to the memory location the value is allocated to.
    let ref: IRValue

    // The type qualifiers of the value's type (e.g. @ref, @shd, ...).
    let qualifiers: TypeQualifier

    let read : () -> IRValue
    let write: (IRValue) -> ()

}
