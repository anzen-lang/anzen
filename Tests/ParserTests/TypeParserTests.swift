import XCTest

import AST
@testable import Parser

class TypeParserTests: XCTestCase, ParserTestCase {

  func testParseTypeIdentifier() {
    var pr: Parser.Result<TypeSign?>

    pr = parse("Int", with: Parser.parseTypeSign)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: TypeIdent.self))
    if let identifier = pr.value as? TypeIdent {
      assertThat(identifier.name, .equals("Int"))
      assertThat(identifier.specializations, .isEmpty)
    }

    pr = parse("Map<Key=String, Value=Int>", with: Parser.parseTypeSign)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: TypeIdent.self))
    if let identifier = pr.value as? TypeIdent {
      assertThat(identifier.name, .equals("Map"))
      assertThat(identifier.specializations, .count(2))
      assertThat(identifier.specializations.keys, .contains("Key"))
      assertThat(identifier.specializations.keys, .contains("Value"))
    }

    let source = "Map < Key = String , Value = Int , >"
      .split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseTypeSign)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: TypeIdent.self))
  }

  func testParseFunctionSignature() {
    var pr: Parser.Result<TypeSign?>

    pr = parse("() -> Int", with: Parser.parseTypeSign)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunSign.self))
    if let signature = pr.value as? FunSign {
      assertThat(signature.parameters, .isEmpty)
      assertThat(signature.codomain, .isInstance(of: QualTypeSign.self))
    }

    pr = parse("(a: Int, _: Int, c: Int) -> Int", with: Parser.parseTypeSign)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunSign.self))
    if let signature = pr.value as? FunSign {
      assertThat(signature.parameters, .count(3))
      if signature.parameters.count > 2 {
        assertThat(signature.parameters[0].label, .equals("a"))
        assertThat(signature.parameters[0].typeAnnotation, .isInstance(of: QualTypeSign.self))

        assertThat(signature.parameters[1].label, .isNil)
        assertThat(signature.parameters[1].typeAnnotation, .isInstance(of: QualTypeSign.self))

        assertThat(signature.parameters[2].label, .equals("c"))
        assertThat(signature.parameters[2].typeAnnotation, .isInstance(of: QualTypeSign.self))
      }
    }

    let source = "( a : Int , _ : Int , c : Int , ) -> Int"
      .split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseTypeSign)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunSign.self))
  }

  func testParseEnclosedType() {
    var pr: Parser.Result<TypeSign?>

    pr = parse("(Int)", with: Parser.parseTypeSign)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: TypeIdent.self))

    let source = "( Int )".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseTypeSign)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: TypeIdent.self))
  }

  func testParseQualifiedType() {
    var pr: Parser.Result<QualTypeSign?>

    pr = parse("@mut", with: Parser.parseQualSign)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: QualTypeSign.self))
    assertThat(pr.value?.qualifiers ?? [], .contains(.mut))
    assertThat(pr.value?.signature, .isNil)

    pr = parse("@cst", with: Parser.parseQualSign)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: QualTypeSign.self))
    assertThat(pr.value?.qualifiers ?? [], .contains(.cst))
    assertThat(pr.value?.signature, .isNil)

    pr = parse("Int", with: Parser.parseQualSign)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: QualTypeSign.self))
    assertThat(pr.value?.qualifiers ?? [], .isEmpty)
    assertThat(pr.value?.signature, .isInstance(of: TypeIdent.self))

    pr = parse("@mut Int", with: Parser.parseQualSign)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: QualTypeSign.self))
    assertThat(pr.value?.qualifiers ?? [], .contains(.mut))
    assertThat(pr.value?.signature, .isInstance(of: TypeIdent.self))

    let source = "@mut Int".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseQualSign)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: QualTypeSign.self))
  }

  func testParseQualifiedFunctionSignature() {
    var pr: Parser.Result<QualTypeSign?>

    pr = parse("(a: Int, _: Int, c: Int) -> Int", with: Parser.parseQualSign)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: QualTypeSign.self))
    assertThat(pr.value?.qualifiers ?? [], .isEmpty)
    assertThat(pr.value?.signature, .isInstance(of: FunSign.self))
  }

  func testParseEnclosedQualifiedType() {
    var pr: Parser.Result<QualTypeSign?>

    pr = parse("(@mut)", with: Parser.parseQualSign)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: QualTypeSign.self))
    assertThat(pr.value?.qualifiers ?? [], .contains(.mut))

    pr = parse("(@mut Int)", with: Parser.parseQualSign)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: QualTypeSign.self))
    assertThat(pr.value?.qualifiers ?? [], .contains(.mut))
    assertThat(pr.value?.signature, .isInstance(of: TypeIdent.self))

    let source = "( @mut Int )".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseQualSign)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: QualTypeSign.self))
  }

}
