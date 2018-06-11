import XCTest

import AST
import Parser
import Sema
import Utils
import SystemKit

class StringBuffer: TextOutputStream {

  func write(_ string: String) {
    storage.write(string)
  }

  var storage: String = ""

}

class SemaTests: XCTestCase {

  override func setUp() {
    guard let anzenPathname = System.environment["ANZENPATH"]
      else { fatalError("missing environment variable 'ANZENPATH'") }
    anzenPath = Path(pathname: anzenPathname)

    guard let entryPathname = System.environment["ANZENTESTPATH"]
      else { fatalError("missing environment variable 'ANZENTESTPATH'") }
    entryPath = Path(pathname: entryPathname)
    Path.workingDirectory = entryPath
  }

  var anzenPath: Path = .workingDirectory
  var entryPath: Path = .workingDirectory

  func testTypeInferenceFixtures() {
    var fixtures: [String: Path] = [:]
    var outputs: [String: Path] = [:]
    for entry in entryPath.joined(with: "inference") {
      if entry.fileExtension == "anzen" {
        fixtures[String(entry.pathname.dropLast(6))] = entry
      } else if entry.fileExtension == "output" {
        outputs[String(entry.pathname.dropLast(7))] = entry
      }
    }

    for testCase in fixtures {
      let loader = DefaultModuleLoader(verbosity: .normal)
      let context = ASTContext(anzenPath: anzenPath, loadModule: loader.load)

      let module = try! context.getModule(moduleID: .local(testCase.value))
      let testResult = StringBuffer()
      try! ASTDumper(outputTo: testResult).visit(module)

      if let output = outputs[testCase.key] {
        let expectation = TextFile(path: output)
        XCTAssertLinesEqual(testResult.storage, try! expectation.read(), path: testCase.value)
      } else {
        let outputPath = Path(pathname: String(testCase.value.pathname.dropLast(6)) + ".output")
        let expectation = TextFile(path: outputPath)
        try! expectation.write(testResult.storage)
        print("⚠️  no oracle for '\(testCase.value.filename!)', regression test case created now")
      }
    }
  }

  #if !os(macOS)
  static var allTests = [
    ("testTypeInferenceFixtures", testTypeInferenceFixtures),
  ]
  #endif

}

private func XCTAssertLinesEqual(_ lhs: String, _ rhs: String, path: Path) {
  let lhsLines = lhs.split(separator: "\n")
  let rhsLines = rhs.split(separator: "\n")

  var errors: [(lineno: Int, lhs: String, rhs: String)] = []
  for (i, (ll, rl)) in zip(lhsLines, rhsLines).enumerated() {
    if ll != rl {
      errors.append((lineno: i + 1, lhs: String(ll), rhs: String(rl)))
    }
  }

  guard errors.isEmpty else {
    XCTFail("⚠️  \(path.filename!)")
    for (lineno, ll, rl) in errors {
      print("  L\(lineno) | expected: " + ll.trimmingCharacters(in: [" "]).styled("green"))
      print("  L\(lineno) | actual  : " + rl.trimmingCharacters(in: [" "]).styled("red"))
    }
    return
  }

  guard lhsLines.count == rhsLines.count else {
    XCTFail("⚠️  \(path.filename!): different line count")
    return
  }
}
