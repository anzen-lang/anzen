#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

import AST
import AnzenLib
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

// Create an AST context. This will be used to parse and analyze Anzen modules, before they are
// eventually forwarded to an interpreter or code generator.
let logger = DefaultLogger(verbosity: .debug)
let loader = DefaultModuleLoader(logger: logger)
let context = ASTContext(anzenPath: anzenPath, moduleLoader: loader)

// Load the given input file as the main module.
let main = context.getModule(moduleID: .local(inputPath))
