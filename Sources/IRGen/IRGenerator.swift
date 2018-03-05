import AnzenAST
import AnzenTypes
import LLVM
import Utils

public struct IRGenerator: ASTVisitor {

    public init(moduleName: String) {
        self.module  = Module(name: moduleName, context: self.context)
        self.builder = IRBuilder(module: self.module)
        self.layout  = self.module.dataLayout

        // TODO: Add relevant optimization passes.
        self.functionVerifier = FunctionPassManager(module: self.module)
    }

    public mutating func transform(_ module: ModuleDecl, asEntryPoint: Bool = false) -> String {
        // If the module's the entry point, we implicitly enclose it in a "main" function.
        if asEntryPoint {
            let fn = self.builder.addFunction(
                "main", type: LLVM.FunctionType(argTypes: [], returnType: IntType.int32))
            let entry = fn.appendBasicBlock(named: "entry", in: self.context)
            self.builder.positionAtEnd(of: entry)
            self.locals.push([:])
        }

        try! self.visit(module)

        if let fn = self.module.function(named: "main") {
            self.builder.positionAtEnd(of: fn.lastBlock!)
            self.builder.buildRet(IntType.int32.constant(0))
            self.functionVerifier.run(on: fn)
        }

        return self.module.description
    }

    func buildEntryAlloca(
        in function: Function, typed llvmType: IRType, named name: String? = nil)
        -> IRValue
    {
        let currentBlock = self.builder.insertBlock
        let entryBlock   = function.entryBlock!

        if let firstInst = entryBlock.firstInstruction {
            self.builder.position(firstInst, block: entryBlock)
        }

        let alloca = name != nil
            ? self.builder.buildAlloca(type: llvmType, name: name!)
            : self.builder.buildAlloca(type: llvmType)

        if let block = currentBlock {
            self.builder.positionAtEnd(of: block)
        }

        return alloca
    }

    mutating func buildBinding(to property: Property, op: Operator, valueOf node: Node) throws {
        // Generate the rvalue.
        try self.visit(node)

        switch op {
        case .cpy:
            var (rvalue, storage) = self.stack.pop()!
            if storage == .reference {
                rvalue = self.builder.buildLoad(rvalue)
            }
            self.builder.buildStore(rvalue, to: property.ref)

        default:
            fatalError("Unexpected binding operator: '\(op)'")
        }
    }

    /// The LLVM module currently being generated.
    let module : Module

    /// The LLVM builder that will build instructions.
    let builder: IRBuilder

    /// The LLVM context the module lives in.
    let context: Context = Context.global

    /// The data layout for the current target
    let layout: TargetData

    /// A stack that lets us accumulate the LLVM values of expressions, before they are consumed
    /// by a statement.
    var stack: Stack<(IRValue, ValueStorage)> = []

    /// A stack of maps of local symbols.
    var locals: Stack<[String: Property]> = []

    /// A map of global symbols.
    var globals: [String: IRGlobal] = [:]

    /// LLVM sanity checker.
    let functionVerifier: FunctionPassManager

    // MARK: Runtime types and functions

    /// Returns a pointer to `managed_object`.
    var managed_object: LLVM.IRType {
        if let ty = self.module.type(named: "managed_object") {
            return ty
        }

        let ty = self.builder.createStruct(name: "managed_object")
        ty.setBody([ IntType.int8*, IntType.int64 ])
        return ty
    }

    /// Returns a pointer to the C's `malloc` function, declaring it if necessary.
    var malloc: Function {
        if let fn = self.module.function(named: "malloc") {
            return fn
        }

        let fnTy = LLVM.FunctionType(argTypes: [IntType.int64], returnType: IntType.int8*)
        var fn = self.builder.addFunction("malloc", type: fnTy)
        fn.linkage = .external
        fn.callingConvention = .c
        return fn
    }

    /// Returns a pointer to the C's `printf` function, declaring it if necessary.
    var printf: Function {
        if let fn = self.module.function(named: "printf") {
            return fn
        }

        let fnTy = FunctionType(
            argTypes: [ IntType.int8* ], returnType: IntType.int32, isVarArg: true)
        var fn = self.builder.addFunction("printf", type: fnTy)
        fn.linkage = .external
        fn.callingConvention = .c
        return fn
    }

}

enum ValueStorage {

    case reference
    case value

}

