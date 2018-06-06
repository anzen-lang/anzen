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

func < (lhs: ASTError, rhs: ASTError) -> Bool {
  let lname = lhs.node.module.id?.qualifiedName ?? ""
  let rname = rhs.node.module.id?.qualifiedName ?? ""
  return lname == rname
    ? lhs.node.range.start < rhs.node.range.start
    : lname < rname
}

// ---

guard let cAnzenPath = getenv("ANZENPATH")
  else { fatalError("missing environment variable 'ANZENPATH'") }
let anzenPath = Path(url: String(cString: cAnzenPath))
let entryPath = Path(url: "/Users/alvae/Developer/Anzen/anzen/InputSamples")

let loader = DefaultModuleLoader(verbosity: .debug)
let context = ASTContext(anzenPath: anzenPath, entryPath: entryPath, loadModule: loader.load)

let main: ModuleDecl
do {

  main = try context.getModule(moduleID: .local("main.anzen"))
  guard context.errors.isEmpty else {
    // Print the errors, sorted.
    for error in context.errors.sorted(by: <) {
      Console.err.diagnose(error: error)
    }
    exit(-1)
  }

} catch let error as ParseError {

  // FIXME: Parse errors shouldn't get a special treatment, but should be added to the AST context
  // by the module loader. When that's done, we won't have to catch them here.
  if let range = error.range {
    let filename = (range.start.source as? TextFile)?.filepath.basename ?? "<unknown>"
    let title = try! StyledString(
      "{\(filename)::\(range.start.line)::\(range.start.column):::bold} " +
      "{error:::bold,red} {\(error.cause):bold}"
    )
    Console.err.print(title)
    Console.err.diagnose(range: range)
  }
  exit(-1)

}

//let printer = ASTUnparser(in: Console.out, includeType: true)
//try! printer.visit(main)

let dumper = ASTDumper(console: Console.out)
try dumper.visit(main)
