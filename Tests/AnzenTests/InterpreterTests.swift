import XCTest

import AST
import AnzenIR
import AnzenLib
import Interpreter
import SystemKit
import Utils

class InterpreterTests: XCTestCase {

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

  func testInterpreterFixtures() {
    var fixtures: [String: Path] = [:]
    var outputs: [String: Path] = [:]
    for entry in entryPath.joined(with: "interpreter") {
      if entry.fileExtension == "anzen" {
        fixtures[String(entry.pathname.dropLast(6))] = entry
      } else if entry.fileExtension == "output" {
        outputs[String(entry.pathname.dropLast(7))] = entry
      }
    }

    for testCase in fixtures {
      let loader = DefaultModuleLoader()
      let context = ASTContext(anzenPath: anzenPath, moduleLoader: loader)

      guard let module = context.getModule(moduleID: .local(testCase.value)) else {
        XCTFail("❌ failed to load '\(testCase.value.filename!)'")
        continue
      }

      let driver = AIREmissionDriver()
      let unit = driver.emitMainUnit(module, context: context)
      guard let mainFn = unit.functions["main"] else {
        XCTFail("❌ failed to load '\(testCase.value.filename!)'")
        continue
      }

      let testResult = StringBuffer()
      let interpreter = Interpreter(stdout: testResult)

      do {
        try interpreter.invoke(function: mainFn)
      } catch {
        // Explicitly silence errors.
      }

      if let output = outputs[testCase.key] {
        let expectation = TextFile(path: output)
        XCTAssertLinesEqual(try! expectation.read(), testResult.value, path: testCase.value)
        print("✅  regression test succeeded for '\(testCase.value.filename!)'")
      } else {
        let outputPath = Path(pathname: String(testCase.value.pathname.dropLast(6)) + ".output")
        let expectation = TextFile(path: outputPath)
        try! expectation.write(testResult.value)
        print("⚠️  no oracle for '\(testCase.value.filename!)', regression test case created now")
      }
    }
  }

}
