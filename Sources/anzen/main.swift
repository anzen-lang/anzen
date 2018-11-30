#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

import AST
import AnzenLib
import Interpreter
import SystemKit

// The `ANZENPATH` is the directory containing Anzen's built-in interfaces, and its standard
// library. It defaults to `/usr/local/lib/anzen/core`, but can be overriden if the environment
// variable `ANZENPATH` is set.
let anzenPathname = System.environment["ANZENPATH"] ?? "/usr/local/lib/anzen/core"
let anzenPath = Path(pathname: anzenPathname)

// Get the path to the input file.
guard CommandLine.arguments.count > 1
  else { fatalError("no input file") }
let inputPath = Path(pathname: CommandLine.arguments[1])

// Set the working directory to the that of the input file, so that all local imports are relative
// to the main module.
guard let mainDirectory = inputPath.parent,
      let mainPathname = inputPath.filename
  else { fatalError("'\(inputPath)' is not a valid module entry") }
Path.workingDirectory = mainDirectory
let mainPath = Path(pathname: mainPathname)

// Create an AST context. This will be used to parse and analyze Anzen modules, before they are
// eventually forwarded to an interpreter or code generator.
let logger = DefaultLogger(verbosity: .debug)
let loader = DefaultModuleLoader(logger: logger)
let context = ASTContext(anzenPath: anzenPath, moduleLoader: loader)

// Load the given input file as the main module.
guard let mainModule = context.getModule(moduleID: .local(mainPath))
  else { exit(1) }

// Pretty-print the typed AST.
// try ASTDumper(outputTo: System.err).visit(main)
try ASTUnparser(console: System.err, includeType: true).visit(mainModule)

// Compile the module into AIR.
let mainUnit = AIRUnit(name: mainModule.id!.qualifiedName, isMain: true)
let builder = AIRBuilder(unit: mainUnit, context: context)
let emitter = AIREmitter(builder: builder)
try emitter.visit(mainModule)

System.err.print(mainUnit)

// Interpret the main module.
guard let mainFn = mainUnit.functions["main"]
  else { fatalError("no main function") }

let interpreter = AIRInterpreter()
interpreter.invoke(function: mainFn)
let status: Int32 = 0

// Exit with the interpreter's status.
exit(status)
