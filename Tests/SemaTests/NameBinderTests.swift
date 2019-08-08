import XCTest

import AST
import Parser
import SystemKit
import Utils

@testable import Sema

class NameBinderTests: XCTestCase {

  let anzenPath = Path(pathname: System.environment["ANZENPATH"] ?? "/usr/local/include/Anzen")
  var context: CompilerContext!

  override func setUp() {
    context = try! CompilerContext(anzenPath: anzenPath, loader: Loader())
  }

  func testNothing() {
  }

}

struct Loader: ModuleLoader {

  func load(module: Module, fromDirectory dir: Path, in context: CompilerContext)
    throws -> Module
  {
    // This skips the standard library's loading!
    return module
  }

  public func load(module: Module, fromText buffer: TextInputBuffer, in context: CompilerContext)
    throws -> Module
  {
    // Parse the module.
    let source = SourceRef(name: module.id, buffer: buffer)
    let parser = try Parser(source: source, module: module)
    let (decls, issues) = parser.parse()
    module.decls.append(contentsOf: decls)
    module.issues.formUnion(issues)

    ParseFinalizerPass(module: module).process()
    module.state = .parsed

    // Typecheck the module.
    NameBinderPass(module: module, context: context).process()

    return module
  }

}
