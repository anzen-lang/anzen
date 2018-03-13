import AnzenAST
import AnzenTypes
import LLVM
import Utils

/// The native `Int` type for the generated IR.
public let NativeInt = IntType.int64

/// LLVM IR generator.
public struct IRGenerator: ASTVisitor {

    public init(moduleName: String, withOptimizations: Bool = false) {
        llvmModule = Module(name: moduleName, context: context)
        builder = IRBuilder(module: llvmModule)

        passManager = FunctionPassManager(module: llvmModule)
        if withOptimizations {
            passManager.add(.basicAliasAnalysis)
            passManager.add(.instructionCombining)
            passManager.add(.reassociate)
            passManager.add(.gvn)
            passManager.add(.cfgSimplification)
            passManager.add(.promoteMemoryToRegister)
            passManager.add(.tailCallElimination)
            passManager.add(.loopUnroll)
        }
    }

    public mutating func transform(_ module: ModuleDecl, asEntryPoint: Bool = false) -> Module {
        // Forward-declares types and functions.
        var declarator = ForwardDeclarator(builder: builder)
        try! declarator.visit(module)

        // If the module's the entry point, we implicitly enclose it in a "main" function.
        if asEntryPoint {
            let fn = builder.addFunction(
                "main", type: LLVM.FunctionType(argTypes: [], returnType: IntType.int32))
            let entry = fn.appendBasicBlock(named: "entry", in: context)
            builder.positionAtEnd(of: entry)
            symbolMaps.push([:])
        }

        try! visit(module)

        if let fn = llvmModule.function(named: "main") {
            builder.positionAtEnd(of: fn.lastBlock!)
            builder.buildRet(IntType.int32.constant(0))
            passManager.run(on: fn)
        }

        return llvmModule
    }

    /// The LLVM module currently being generated.
    let llvmModule : Module

    /// The LLVM builder that will build instructions.
    let builder: IRBuilder

    /// The LLVM context the module lives in.
    let context: Context = Context.global

    /// A stack that lets us accumulate the LLVM values of expressions, before they are consumed
    /// by a statement.
    var stack: Stack<Emittable> = []

    /// A stack of maps associating symbols to emittable values.
    var symbolMaps: Stack<[AnzenAST.Symbol: Emittable]> = []

    /// A stack of return properties.
    ///
    /// Anzen functions return their value by binding a value to their first parameter (see copy
    /// elision). Because this virtual parameter isn't bound to a symbol of the module, we can't
    /// retrieve it from the symbol map. Hence, we need an additional register to keep track of
    /// the property to which bind return values.
    var returnProps: Stack<Property> = []

    /// The function pass manager that performs optimizations.
    let passManager: FunctionPassManager

    // MARK: Runtime types and functions

    /// Returns a pointer to the C's `printf` function, declaring it if necessary.
    var printf: Function {
        if let fn = llvmModule.function(named: "printf") {
            return fn
        }

        let fnTy = FunctionType(
            argTypes: [ IntType.int8* ], returnType: IntType.int32, isVarArg: true)
        let fn = builder.addFunction("printf", type: fnTy)
        fn.callingConvention = .c
        return fn
    }

}

extension IRBuilder {

    func buildEntryAlloca(in function: Function, type: IRType, name: String? = nil) -> IRValue {
        let currentBlock = insertBlock
        let entryBlock = function.entryBlock!

        if let firstInst = entryBlock.firstInstruction {
            position(firstInst, block: entryBlock)
        }

        let alloca = name != nil
            ? buildAlloca(type: type, name: name!)
            : buildAlloca(type: type)

        if let block = currentBlock { positionAtEnd(of: block) }
        return alloca
    }

    func buildCallToMalloc(_ size: Int) -> IRValue {
        var fn = module.function(named: "malloc")
        if fn == nil {
            let ty = FunctionType(argTypes: [NativeInt], returnType: IntType.int8*)
            fn = addFunction("malloc", type: ty)
            fn!.callingConvention = .c
        }
        return buildCall(fn!, args: [NativeInt.constant(size)])
    }

}
