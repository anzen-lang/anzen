import XCTest
import AssertThat
import SystemKit

import AnzenLib
import Parser
import Sema
import Utils

let program =
"""
extension Foo {
  let a: Self
  let b: Foo
  let c: T
  let d: Bar
  let e: Ham

  struct Baz {}
}

extension Foo {
  struct Ham {
    let r: Bar::Qux
  }
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
    let p: Baz
    let q: Qux
  }
}
"""

class NameBinderTests: XCTestCase {

  func testNameBinding() {
    // Create a test module.
    let anzen = Anzen()
    let (_, module) = anzen.createModule(named: "Test")

    // Parse the program.
    XCTAssertNoThrow(try anzen.parse(program, into: module))
    ParseFinalizerPass(module: module).process()
    module.state = .parsed

    // Run the name binding pass.
    NameBinderPass(module: module, context: anzen.context).process()
    assertThat(module.issues, .isEmpty)
  }

}
