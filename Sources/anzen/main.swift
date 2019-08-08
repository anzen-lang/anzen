import AST
import Parser
import SystemKit

do {
  // Create the compiler context.
  let anzenPath = Path(pathname: System.environment["ANZENPATH"] ?? "/usr/local/include/Anzen")
  let loader = ConcreteModuleLoader ()
  let context: CompilerContext
  do {
    context = try CompilerContext(anzenPath: anzenPath, loader: loader)
  } catch {
    System.err.write("error: ".styled("red") + String(describing: error) + "\n")
    System.exit(status: 1)
  }

//  let module = Module(id: "<test>")
//  let input = TextFile(
//    path: Path(pathname: "/Users/alvae/Developer/Anzen/anzen/InputSamples/main.anzen"))
//
//  let parser = try Parser(
//    source: SourceRef(name: "main.anzen", buffer: input),
//    module: module,
//    isMainCodeDecl: true)
//  let (decls, issues) = parser.parse()
//  module.decls.append(contentsOf: decls)
//  module.issues.formUnion(issues)
//
//  ParseFinalizer(module: module).process()

  let reporter = ConsoleIssueReporter()
  for moduleID in context.modules.keys.sorted() {
    for issue in context.modules[moduleID]!.issues.sorted(by: { $0 < $1 }) {
      reporter.report(issue)
    }
  }
}
