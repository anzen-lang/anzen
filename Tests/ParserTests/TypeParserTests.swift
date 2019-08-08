import XCTest

import AST
@testable import Parser

class TypeParserTests: XCTestCase, ParserTestCase {

  func testParseTypeIdentifier() {
    var pr: ParseResult<TypeSign?>

    pr = parse("Int", with: Parser.parseTypeSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: IdentSign.self))
    if let ident = pr.value as? IdentSign {
      assertThat(ident.name, .equals("Int"))
      assertThat(ident.specArgs, .isEmpty)
    }

    pr = parse("Map<Key=String, Value=Int>", with: Parser.parseTypeSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: IdentSign.self))
    if let ident = pr.value as? IdentSign {
      assertThat(ident.name, .equals("Map"))
      assertThat(ident.specArgs, .count(2))
      assertThat(ident.specArgs.keys, .contains("Key"))
      assertThat(ident.specArgs.keys, .contains("Value"))
    }

    let source = "Map < Key = String , Value = Int , >"
      .split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseTypeSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: IdentSign.self))
  }

  func testParseImplicitNestedIdentSign() {
    var pr: ParseResult<TypeSign?>

    pr = parse("::Element", with: Parser.parseTypeSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: ImplicitNestedIdentSign.self))
    if let select = pr.value as? ImplicitNestedIdentSign {
      assertThat(select.ownee.name, .equals("Element"))
    }
  }

  func testParseNestedIdentSign() {
    var pr: ParseResult<TypeSign?>

    pr = parse("Array::Element", with: Parser.parseTypeSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: NestedIdentSign.self))
    if let select = pr.value as? NestedIdentSign {
      assertThat(select.owner, .isInstance(of: IdentSign.self))
      assertThat(select.ownee.name, .equals("Element"))
    }

    let source = "Array < Element = String , > ::Element"
      .split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseTypeSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: NestedIdentSign.self))
  }

  func testParseFunSign() {
    var pr: ParseResult<TypeSign?>

    pr = parse("() -> Int", with: Parser.parseTypeSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunSign.self))
    if let sign = pr.value as? FunSign {
      assertThat(sign.params, .isEmpty)
      assertThat(sign.codom, .isInstance(of: QualTypeSign.self))
    }

    pr = parse("(a: Int, _: Int, c: Int) -> Int", with: Parser.parseTypeSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunSign.self))
    if let sign = pr.value as? FunSign {
      assertThat(sign.params, .count(3))
      if sign.params.count > 2 {
        assertThat(sign.params[0].label, .equals("a"))
        assertThat(sign.params[0].sign, .isInstance(of: QualTypeSign.self))

        assertThat(sign.params[1].label, .isNil)
        assertThat(sign.params[1].sign, .isInstance(of: QualTypeSign.self))

        assertThat(sign.params[2].label, .equals("c"))
        assertThat(sign.params[2].sign, .isInstance(of: QualTypeSign.self))
      }
    }

    let source = "( a : Int , _ : Int , c : Int , ) -> Int"
      .split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseTypeSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunSign.self))
  }

  func testParseParenthesized() {
    var pr: ParseResult<TypeSign?>

    pr = parse("(Int)", with: Parser.parseTypeSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: IdentSign.self))

    let source = "( Int )".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseTypeSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: IdentSign.self))
  }

  func testParseQualTypeSign() {
    var pr: ParseResult<QualTypeSign?>

    pr = parse("@mut", with: Parser.parseQualSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: QualTypeSign.self))
    assertThat(pr.value?.quals ?? []) { $0.contains(.mut) }
    assertThat(pr.value?.sign, .isNil)

    pr = parse("@cst", with: Parser.parseQualSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: QualTypeSign.self))
    assertThat(pr.value?.quals ?? []) { $0.contains(.cst) }
    assertThat(pr.value?.sign, .isNil)

    pr = parse("Int", with: Parser.parseQualSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: QualTypeSign.self))
    assertThat(pr.value?.quals ?? []) { $0.isEmpty }
    assertThat(pr.value?.sign, .isInstance(of: IdentSign.self))

    pr = parse("@mut Int", with: Parser.parseQualSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: QualTypeSign.self))
    assertThat(pr.value?.quals ?? []) { $0.contains(.mut) }
    assertThat(pr.value?.sign, .isInstance(of: IdentSign.self))

    let source = "@mut Int".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseQualSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: QualTypeSign.self))
  }

  func testParseQualFunSign() {
    var pr: ParseResult<QualTypeSign?>

    pr = parse("(a: Int, _: Int, c: Int) -> Int", with: Parser.parseQualSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: QualTypeSign.self))
    assertThat(pr.value?.quals ?? []) { $0.isEmpty }
    assertThat(pr.value?.sign, .isInstance(of: FunSign.self))
  }

  func testParseEnclosedQualifiedType() {
    var pr: ParseResult<QualTypeSign?>

    pr = parse("(@mut)", with: Parser.parseQualSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: QualTypeSign.self))
    assertThat(pr.value?.quals ?? []) { $0.contains(.mut) }

    pr = parse("(@mut Int)", with: Parser.parseQualSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: QualTypeSign.self))
    assertThat(pr.value?.quals ?? []) { $0.contains(.mut) }
    assertThat(pr.value?.sign, .isInstance(of: IdentSign.self))

    let source = "( @mut Int )".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseQualSign)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: QualTypeSign.self))
  }

}
