import SystemKit

import AnzenLib
import AST

// Read the command line.
var dumpAST = false
var pathname: String?

for argument in CommandLine.arguments.dropFirst() {
  switch argument {
  case "--dump-ast":
    dumpAST = true
  default:
    pathname = argument
  }
}

guard pathname != nil else {
  System.err.write("error: ".styled("red") + "no input file\n")
  System.exit(status: 1)
}

// Create a compiler instance.
let anzen = Anzen()
let module: Module

do {
  // Load Anzen's standard library.
  // let includePath = Path(pathname: System.environment["ANZENPATH"] ?? "/usr/local/include/Anzen")
  // try anzen.loadModule(fromPath: includePath.joined(with: "stdlib.anzen"), withName: "Anzen")

  // Load the given path as a module.
  (_, module) = try anzen.loadModule(fromPath: Path(pathname: pathname!))
} catch {
  System.err.write("error: ".styled("red") + String(describing: error) + "\n")
  System.exit(status: 1)
}

// Report all issues.
let reporter = ConsoleIssueReporter()
for moduleID in anzen.context.modules.keys.sorted() {
  for issue in anzen.context.modules[moduleID]!.issues.sorted(by: { $0 < $1 }) {
    reporter.report(issue)
  }
}

if dumpAST {
  module.dump()
}
