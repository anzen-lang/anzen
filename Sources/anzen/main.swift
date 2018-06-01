import AST
import Sema
import Utils

// ---

let searchPaths = [
  "/Users/alvae/Developer/Anzen/micro-anzen/Sources/Core/",
  "/Users/alvae/Developer/Anzen/anzen/InputSamples/",
]

let loader  = LocalModuleLoader(searchPaths: searchPaths, verbosity: .debug)
let context = ASTContext(loadModule: loader.load)
let main    = try! context.getModule(moduleID: .local(name: "main"))
var printer = ASTPrinter(in: Console.out, includeType: true)
try! printer.visit(main)
