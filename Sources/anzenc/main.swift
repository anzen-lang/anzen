#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif
import AnzenAST
import AnzenLib
import Commander
import LLVM
import Sema
import SwiftShell
import Utils

let main = command(
    Argument<String>("input", description: "Input source"),
    Option("lib", default: "", description: "Library search path(s)"),
    Flag("print-src", default: false, description: "Pretty-print the source as it was parsed."),
    Flag("print-ast", default: false, description: "Print the AST of the input after type-check."),
    Flag("emit-llvm", default: false, description: "Emit the LLVM IR."),
    Flag("optimized", default: false, description: "Compile with optimizations.")
) { input, lib, printSRC, printAST, emitLLVM, optimized in

    // Read the source file.
    let source: String
    do {
        source = try File(path: input).read()
    } catch let error as IOError {
        Console.err.print("error: ", in: [.bold, .red], terminator: "")
        switch error {
        case .fileNotFound(let path):
            Console.err.print("no such file or directory: '\(path)'", in: .bold)
        default:
            Console.err.print("I/O error: '\(error.number)'", in: .bold)
        }
        exit(-1)
    }

    // Parse the source file.
    let ast: AnzenAST.ModuleDecl
    do {
        ast = try AnzenLib.parse(text: source)
    } catch {
        exit(-1)
    }

    // Pretty-print the source if instructed to
    if printSRC { print(ast) }

    // Run the static semantic analysis.
    let semaErrors = AnzenLib.performSema(on: ast)
    guard semaErrors.isEmpty else {
        // Pretty-print each error found during semantic analysis.
        for error in semaErrors {
            Console.err.print("error: ", in: [.bold, .red], terminator: "")
            Console.err.print(error, in: [.bold])
            Console.err.print()
        }
        exit(-1)
    }

    // Print the AST if instructed to.
    if printAST { debugPrint(ast) }

    // Run the LLVM IR code generation.
    let llvmModule = AnzenLib.generateLLVM(of: ast, withOptimizations: optimized)
    if emitLLVM {
        Console.out.print(llvmModule)
    }

    // Compile the module.
    let object = input + ".o"
    let targetMachine = try TargetMachine()
    try targetMachine.emitToFile(module: llvmModule, type: .object, path: object)

    let clangInvocationResult = SwiftShell.run("clang", "-L", lib, "-lanzen-runtime", object)
    if !clangInvocationResult.succeeded {
        Console.err.print(clangInvocationResult.stderror)
    }
    exit(Int32(clangInvocationResult.exitcode))

}

main.run()
