import XCTest

import AssertThat
import AST
@testable import Parser

class StmtParserTests: XCTestCase, ParserTestCase {

  func testParseIfStmt() {
    var pr: ParseResult<ASTNode?>

    pr = parse("if c1 {}", with: Parser.parseStmt)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: IfStmt.self))
    if let conditional = pr.value as? IfStmt {
      assertThat(conditional.elseStmt, .isNil)
    }

    pr = parse("if c1 {} else {}", with: Parser.parseStmt)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: IfStmt.self))
    if let conditional = pr.value as? IfStmt {
      assertThat(conditional.elseStmt, .isInstance(of: BraceStmt.self))
    }

    pr = parse("if c1 {} else if c2 {}", with: Parser.parseStmt)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: IfStmt.self))
    if let conditional = pr.value as? IfStmt {
      assertThat(conditional.elseStmt, .isInstance(of: IfStmt.self))
    }

    let source = "if c1 { } else if c2 { }".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseStmt)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: IfStmt.self))
  }

  func testParseWhileStmt() {
    var pr: ParseResult<ASTNode?>

    pr = parse("while c1 {}", with: Parser.parseStmt)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: WhileStmt.self))

    let source = "while c1 { }".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseStmt)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: WhileStmt.self))
  }

  func testParseReturnStmt() {
    var pr: ParseResult<ASTNode?>

    pr = parse("return", with: Parser.parseStmt)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: ReturnStmt.self))
    if let statement = pr.value as? ReturnStmt {
      assertThat(statement.binding, .isNil)
    }

    pr = parse("return <- 42", with: Parser.parseStmt)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: ReturnStmt.self))
    if let statement = pr.value as? ReturnStmt {
      assertThat(statement.binding?.op.name, .equals("<-"))
      assertThat(statement.binding?.value, .isInstance(of: Expr.self))
    }

    let source = "return <- 42".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseStmt)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: ReturnStmt.self))
  }

  func testParseBinding() {
    var pr: ParseResult<ASTNode?>

    pr = parse("f().x := v[a &- b]", with: Parser.parseStmt)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: BindingStmt.self))
    if let statement = pr.value as? BindingStmt {
      assertThat(statement.op.name, .equals(":="))
    }

    pr = parse("f().x &- v[a &- b]", with: Parser.parseStmt)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: BindingStmt.self))
    if let statement = pr.value as? BindingStmt {
      assertThat(statement.op.name, .equals("&-"))
    }

    pr = parse("f().x <- v[a &- b]", with: Parser.parseStmt)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: BindingStmt.self))
    if let statement = pr.value as? BindingStmt {
      assertThat(statement.op.name, .equals("<-"))
    }

    let source = "f( ) .x <- v [ a &- b , ]".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseStmt)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: BindingStmt.self))
  }

}
