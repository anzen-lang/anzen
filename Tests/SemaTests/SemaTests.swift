import XCTest

import AST
import Parser
import Sema
import Utils

class SemaTests: XCTestCase {

  override func setUp() {
    guard let cAnzenPath = getenv("ANZENPATH")
      else { fatalError("missing environment variable 'ANZENPATH'") }
    let anzenPath = Path(url: String(cString: cAnzenPath))
    loader = DefaultModuleLoader(verbosity: .normal)
    context = ASTContext(
      anzenPath: anzenPath,
      entryPath: .temporaryDirectory,
      loadModule: loader.load)
  }

  var loader: DefaultModuleLoader!
  var context: ASTContext!

  func testPropDeclTypeInference() throws {
    let intType = context.builtinTypes["Int"]!

    try TextFile.withTemporary { file in
      file.write("let x: Int\n")
      let module = try context.getModule(moduleID: .url(file.filepath))

      let decl = module.statements.first as! PropDecl
      XCTAssertEqual(decl.type, intType)
      let signature = decl.typeAnnotation!.signature as! Ident
      XCTAssertEqual(signature.type, intType.metatype)
    }

    try TextFile.withTemporary { file in
      file.write("let x = 0")
      let module = try context.getModule(moduleID: .url(file.filepath))

      let decl = module.statements.first as! PropDecl
      XCTAssertEqual(decl.type, intType)
      XCTAssertEqual(decl.initialBinding!.value.type, intType)
    }

    try TextFile.withTemporary { file in
      file.write("let x: Int = 0")
      let module = try context.getModule(moduleID: .url(file.filepath))

      let decl = module.statements.first as! PropDecl
      XCTAssertEqual(decl.type, intType)
    }

    try TextFile.withTemporary { file in
      file.write("let x: Int = \"text\"")
      _ = try context.getModule(moduleID: .url(file.filepath))
      XCTAssertEqual(context.errors.count, 1)
    }
  }

  func testFunDeclTypeInference() throws {
    let intType = context.builtinTypes["Int"]!
    let boolType = context.builtinTypes["Bool"]!

    let xi_yb_to_i = context.getFunctionType(
      from: [Parameter(label: "x", type: intType), Parameter(label: "y", type: boolType)],
      to: intType)

    try TextFile.withTemporary { file in
      file.write("fun mono(x: Int, y: Bool) -> Int\n")
      let module = try context.getModule(moduleID: .url(file.filepath))

      let decl = module.statements.first as! FunDecl
      XCTAssertEqual(decl.type, xi_yb_to_i)
      XCTAssertEqual(decl.parameters[0].type, intType)
      XCTAssertEqual(decl.parameters[1].type, boolType)
      let codomain = (decl.codomain as! QualSign).signature as! Ident
      XCTAssertEqual(codomain.type, intType.metatype)
    }
  }

  #if !os(macOS)
  static var allTests = [
    ("testPropDeclTypeInference", testPropDeclTypeInference),
    ("testFunDeclTypeInference", testFunDeclTypeInference),
  ]
  #endif

}
