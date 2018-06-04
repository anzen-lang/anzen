#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

import AST
import Parser
import Sema
import Utils

// ---

guard let cAnzenPath = getenv("ANZENPATH")
  else { fatalError("missing environment variable 'ANZENPATH'") }
let anzenPath = String(cString: cAnzenPath)

let searchPaths = [
  anzenPath + "/Sources/Core/",
  anzenPath + "/InputSamples/",
]

let loader = LocalModuleLoader(searchPaths: searchPaths, verbosity: .debug)
let context = ASTContext(loadModule: loader.load)

let main: ModuleDecl
do {

  main = try context.getModule(moduleID: .local(name: "main"))
  guard context.errors.isEmpty else {
    exit(-1)
  }

} catch let error as ParseError {

  // FIXME: Parse errors shouldn't get a special treatment, but should be added to the AST context
  // by the module loader. When that's done, we won't have to catch them here.
  if let range = error.range {
    let filename = (range.start.source as? TextFile)?.basename ?? "<unknown>"
    let title = try! StyledString(
      "{\(filename)::\(range.start.line)::\(range.start.column):::bold} " +
      "{error:::bold,red} " +
      error.cause.description.styled("bold")
    )
    Console.err.print(title)
    Console.err.diagnose(range: range)
  }
  exit(-1)

}

var printer = ASTPrinter(in: Console.out, includeType: false)
try! printer.visit(main)
