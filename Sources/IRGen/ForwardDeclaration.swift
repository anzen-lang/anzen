import AnzenAST
import AnzenTypes
import LLVM
import Sema

/// LLVM IR generator for types and function forward declarations.
///
/// This visitor should be applied to a module before the code generation of the its statements
/// takes place.
struct ForwardDeclarator: ASTVisitor {

    init(builder: IRBuilder) {
        self.builder = builder
    }

    /// Forward-declares a function, but doesn't emit its body.
    mutating func visit(_ node: FunDecl) throws {
        // Register the function declaration.
        functions.append(node)

        // Create the function object.
        guard let fnTy = node.type! as? AnzenTypes.FunctionType else {
            fatalError("\(node.name) doesn't have a function type")
        }
        let fnName = Mangler.mangle(symbol: node.symbol!)
        let fn = builder.addFunction(fnName, type: builder.buildFunctionType(of: fnTy))

        // Setup function attributes.
        fn.addAttribute(.nounwind, to: .function)
        if !fnTy.codomain.type.equals(to: Builtins.instance.Nothing) {
            fn.addAttribute(.sret, to: .argument(0))
            fn.addAttribute(.noalias, to: .argument(0))
        }
    }

    /// The LLVM builder that will build instructions.
    let builder: IRBuilder

    /// A collection of the functions declared in the module.
    var functions: [FunDecl] = []

}
