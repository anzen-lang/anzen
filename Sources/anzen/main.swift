#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

import AST
import Interpreter
import Parser
import Sema
import Utils
import SystemKit

// ---

func < (lhs: ASTError, rhs: ASTError) -> Bool {
  let lname = lhs.node.module.id?.qualifiedName ?? ""
  let rname = rhs.node.module.id?.qualifiedName ?? ""
  return lname == rname
    ? lhs.node.range.start < rhs.node.range.start
    : lname < rname
}

// ---

guard let anzenPathname = System.environment["ANZENPATH"]
  else { fatalError("missing environment variable 'ANZENPATH'") }
let anzenPath = Path(pathname: anzenPathname)

// FIXME: This should be a parameter of the command line, or default to the parent of the file being
// executed if we run simply `anzen path/to/some/file.anzen`.
Path.workingDirectory = "/Users/alvae/Developer/Anzen/anzen/InputSamples"

let loader = DefaultModuleLoader(verbosity: .debug)
let context = ASTContext(anzenPath: anzenPath, loadModule: loader.load)

let main: ModuleDecl
do {

  main = try context.getModule(moduleID: .local("main.anzen"))
  guard context.errors.isEmpty else {
    // Print the errors, sorted.
    for error in context.errors.sorted(by: <) {
      System.err.diagnose(error: error)
    }
    exit(-1)
  }

  let printer = ASTUnparser(console: System.out, includeType: true)
  try printer.visit(main)
  System.out.print()
  //let dumper = ASTDumper(outputTo: System.out)
  //try dumper.visit(main)

  let mainUnit = AIRUnit(name: main.id!.qualifiedName, isEntry: true)
  let builder = AIRBuilder(unit: mainUnit, context: context)
  let emitter = AIREmitter(builder: builder)
  try emitter.visit(main)
  System.out.print(builder.unit)

  let interpreter = AIRInterpreter()
  interpreter.load(unit: mainUnit)
  guard let entry = mainUnit.functions["main"]
    else { fatalError("program doesn't have a main function") }
  interpreter.invoke(function: entry)

} catch let error as ParseError {

  // FIXME: Parse errors shouldn't get a special treatment, but should be added to the AST context
  // by the module loader. When that's done, we won't have to catch them here.
  if let range = error.range {
    let filename = (range.start.source as? TextFile)?.path.filename ?? "<unknown>"
    let title = try! StyledString(
      "{\(filename)::\(range.start.line)::\(range.start.column):::bold} " +
      "{error:::bold,red} {\(error.cause):bold}"
    )
    System.err.print(title)
    System.err.diagnose(range: range)
  }
  exit(-1)

}
