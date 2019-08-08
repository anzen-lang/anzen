import XCTest

import AssertThat
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

  func testNameBinding() {
    let program = """
    extension Foo {
      let a: Self
      let b: Foo
      let c: T
      let d: Bar
      let e: Ham

      struct Baz {}
    }

    extension Foo {
      struct Ham {}
    }

    extension Foo::Bar {
      let a: Foo
      let b: Bar
      let c: Baz

      struct Qux {}
    }

    struct Foo<T> {
      let z: Self
      let y: T
      let x: Foo
      let w: Bar

      struct Bar {
        let x: Baz
        let y: Qux
      }
    }
    """

    let (module, _) = try! context.loadModule(fromText: program, withID: "<test>")
    assertThat(module.issues, .isEmpty)
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
