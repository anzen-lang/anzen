import AnzenAST
import AnzenTypes
import LLVM
import Utils

/// The native `Int` type for the generated IR.
public let NativeInt = IntType.int64

/// LLVM IR generator.
public struct IRGenerator: ASTVisitor {

    public init(moduleName: String, withOptimizations: Bool = false) {
        self.module  = Module(name: moduleName, context: self.context)
        self.builder = IRBuilder(module: self.module)
        self.layout  = self.module.dataLayout

        self.passManager = FunctionPassManager(module: self.module)
        if withOptimizations {
            self.passManager.add(.basicAliasAnalysis)
            self.passManager.add(.instructionCombining)
            self.passManager.add(.reassociate)
            self.passManager.add(.gvn)
            self.passManager.add(.cfgSimplification)
            self.passManager.add(.promoteMemoryToRegister)
            self.passManager.add(.tailCallElimination)
            self.passManager.add(.loopUnroll)
        }

        self.runtime = Runtime(module: self.module, builder: self.builder)
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
            self.passManager.run(on: fn)
        }

        return self.module.description
    }

    mutating func buildBinding(to property: Property, op: Operator, valueOf node: Node) throws {
        // Generate the rvalue.
        try self.visit(node)
        let value = self.stack.pop()!

        switch op {
        case .cpy: property.bind(to: value, by: .copy)
        case .ref: property.bind(to: value, by: .reference)
        case .mov: property.bind(to: value, by: .move)
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
    var stack: Stack<Emittable> = []

    /// A stack of maps of local symbols.
    var locals: Stack<[String: Emittable]> = []

    /// A map of global symbols.
    var globals: [String: IRGlobal] = [:]

    /// The function pass manager that performs optimizations.
    let passManager: FunctionPassManager

    // MARK: Runtime types and functions

    /// The runtime wrapper.
    let runtime: Runtime

    /// Returns a pointer to `gc_object`.
    ///
    /// A `gc_object` represents a grabage collected object. Each instance of a `gc_object`
    /// comprises a pointer to the managed object, as well as a pointer to a counter that keeps
    /// track of the number of references being made on that object. If this number reaches zero,
    /// the managed object can be garbage collected.
    var gc_object: LLVM.IRType {
        if let ty = self.module.type(named: "struct.gc_object") {
            return ty
        }

        let ty = self.builder.createStruct(name: "struct.gc_object")
        ty.setBody([ IntType.int8*, IntType.int64* ])
        return ty
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

extension IRBuilder {

    func buildEntryAlloca(in function: Function, type: IRType, name: String? = nil) -> IRValue {
        let currentBlock = self.insertBlock
        let entryBlock = function.entryBlock!

        if let firstInst = entryBlock.firstInstruction {
            self.position(firstInst, block: entryBlock)
        }

        let alloca = name != nil
            ? self.buildAlloca(type: type, name: name!)
            : self.buildAlloca(type: type)

        if let block = currentBlock {
            self.positionAtEnd(of: block)
        }

        return alloca
    }

}
