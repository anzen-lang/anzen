import XCTest
import SystemKit

import AnzenLib
import AST
import Utils

class TypeCheckerTests: XCTestCase {

  let includePath = Path(pathname: System.environment["ANZENPATH"] ?? "/usr/local/include/Anzen")
  let testPath = Path(pathname: System.environment["ANZENTESTPATH"] ?? ".")

  override func setUp() {
    Path.workingDirectory = testPath
  }

  func testFixtures() {
    var fixtures: [String: Path] = [:]
    var hasOracle: Set<String> = []

    // Collect all fixtures and their expected result.
    for entry in testPath.joined(with: "inference") {
      if entry.fileExtension == "anzen" {
        fixtures[String(entry.pathname.dropLast(6))] = entry
      } else if entry.fileExtension == "output" {
        hasOracle.insert(String(entry.pathname.dropLast(7)))
      }
    }

    for (name, path) in fixtures {
      // Create a new compiler instance to get a fresh context.
      let anzen = Anzen()

      // Load the fixture as a module.
      let module: Module
      do {
        (_, module) = try anzen.loadModule(fromPath: path)
      } catch {
        XCTFail(error.localizedDescription)
        continue
      }

      // Dump and compare the module's AST.
      var buffer = ""
      module.dump(&buffer)

      let output = Path(pathname: String(path.pathname.dropLast(6)) + ".output")
      let oracle = TextFile(path: output)

      if hasOracle.contains(name) {
        XCTAssertLinesEqual(try! oracle.read(), buffer, path: path)
      } else {
        try! oracle.write(buffer)
        print("created oracle for '\(path.filename!)'")
      }
    }
  }

}
