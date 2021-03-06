import ArgParse
import AST
import AnzenIR
import AnzenLib
import Interpreter
import SystemKit

// MARK: Command line parsing

let parser: ArgumentParser = [
  // Positional arguments.
  .positional("input", description: "Path to the file to compile"),

  // Options.
  .option(
    "show-ast",
    description: "Show the AST at the specified stage of the SEMA (raw, scoped or typed)"),

  // Option flags.
  .flag("show-type-constraints", description: "Show the generated type constraints"),
  .flag("show-air", description: "Show the module's Anzen IR"),
  .flag("help", alias: "h", description: "Display available options"),
]

let parseResult = parser.parseCommandLine()
guard !(parseResult["help"] as! Bool) else {
  var stdout = System.out
  parser.printUsage(to: &stdout)
  System.exit(status: 0)
}

// MARK: Module compilation

// Get the path to the input file.
guard let inputPathname = parseResult["input"] as? String
  else { crash("no input file") }
let inputPath = Path(pathname: inputPathname)

// Set the working directory to the that of the input file, so that all local imports are relative
// to the main module.
guard let mainDirectory = inputPath.parent,
      let mainPathname = inputPath.filename
  else { crash("'\(inputPath)' is not a valid module entry") }
Path.workingDirectory = mainDirectory
let mainPath = Path(pathname: mainPathname)

// The `ANZENPATH` is the directory containing Anzen's built-in interfaces, and its standard
// library. It defaults to `/usr/local/lib/anzen/core`, but can be overriden if the environment
// variable `ANZENPATH` is set.
let anzenPathname = System.environment["ANZENPATH"] ?? "/usr/local/lib/anzen/core"
let anzenPath = Path(pathname: anzenPathname)

// Create the loader config.
var loaderConfig = DefaultModuleLoader.DebugConfig()
let showAST = parseResult["show-ast"] as? String
loaderConfig.showRawAST           = showAST == "raw"
loaderConfig.showScopedAST        = showAST == "scoped"
loaderConfig.showTypedAST         = showAST == "typed"
loaderConfig.showTypeConstraints  = parseResult["show-type-constraints"] as? Bool ?? false

// Create an AST context. This will be used to parse and analyze Anzen modules, before they are
// eventually forwarded to an interpreter or code generator.
let logger = ConsoleLogger()
let loader = DefaultModuleLoader(logger: logger, config: loaderConfig)
let context = ASTContext(anzenPath: anzenPath, moduleLoader: loader)

// Load the given input file as the main module.
guard let mainModule = context.getModule(moduleID: .local(mainPath))
  else { System.exit(status: 1) }

// MARK: AIR code generation

// Compile the module into AIR.
let emissionDriver = AIREmissionDriver()
let mainUnit = emissionDriver.emitMainUnit(mainModule, context: context)

if parseResult["show-air"] as? Bool ?? false {
  System.err.print(mainUnit)
}

// MARK: AIR interpretation

// Interpret the main module.
guard let mainFn = mainUnit.functions["main"]
  else { crash("no main function") }

let interpreter = Interpreter()
do {
  try interpreter.invoke(function: mainFn)
} catch {
  logger.error(error)
}
