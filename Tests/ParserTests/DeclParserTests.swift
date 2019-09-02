import XCTest

import AssertThat
import AST

@testable import Parser

class DeclParserTests: XCTestCase, ParserTestCase {

  func testParsePropDecl() {
    var pr: ParseResult<ASTNode?>

    pr = parse("let x", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: PropDecl.self))
    if let decl = pr.value as? PropDecl {
      assertThat(decl.name, .equals("x"))
      assertThat(decl.isReassignable, .equals(false))
      assertThat(decl.attrs, .isEmpty)
      assertThat(decl.modifiers, .isEmpty)
      assertThat(decl.sign, .isNil)
      assertThat(decl.initializer, .isNil)
    }

    pr = parse("var x", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: PropDecl.self))
    if let decl = pr.value as? PropDecl {
      assertThat(decl.isReassignable, .equals(true))
    }

    pr = parse("let x: @mut Int", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: PropDecl.self))
    if let decl = pr.value as? PropDecl {
      assertThat(decl.sign, .isInstance(of: QualTypeSign.self))
    }

    pr = parse("let x <- 42", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: PropDecl.self))
    if let decl = pr.value as? PropDecl {
      assertThat(decl.initializer?.op.name, .equals("<-"))
      assertThat(decl.initializer?.value, .isInstance(of: IntLitExpr.self))
    }

    pr = parse("let x: @mut Int <- 42", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: PropDecl.self))
    if let decl = pr.value as? PropDecl {
      assertThat(decl.sign, .isInstance(of: QualTypeSign.self))
      assertThat(decl.initializer?.op.name, .equals("<-"))
      assertThat(decl.initializer?.value, .isInstance(of: IntLitExpr.self))
    }

    pr = parse("static mutating let x: Int <- 42", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: PropDecl.self))
    if let decl = pr.value as? PropDecl {
      assertThat(decl.modifiers, .count(2))
      assertThat(decl.modifiers, .contains { $0.kind == .static })
      assertThat(decl.modifiers, .contains { $0.kind == .mutating })
    }

    let source = "static mutating let x : Int <- 42".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseTopLevelNode)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: PropDecl.self))
  }

  func testParseFunDecl() {
    var pr: ParseResult<ASTNode?>

    pr = parse("fun f()", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let decl = pr.value as? FunDecl {
      assertThat(decl.name, .equals("f"))
      assertThat(decl.attrs, .isEmpty)
      assertThat(decl.modifiers, .isEmpty)
      assertThat(decl.kind, .equals(.regular))
      assertThat(decl.genericParams, .isEmpty)
      assertThat(decl.params, .isEmpty)
      assertThat(decl.codom, .isNil)
      assertThat(decl.body, .isNil)
    }

    pr = parse("fun + ()", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let decl = pr.value as? FunDecl {
      assertThat(decl.name, .equals("+"))
    }

    pr = parse("new()", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let decl = pr.value as? FunDecl {
      assertThat(decl.name, .equals("new"))
      assertThat(decl.kind, .equals(.constructor))
    }

    pr = parse("del()", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let decl = pr.value as? FunDecl {
      assertThat(decl.name, .equals("del"))
      assertThat(decl.kind, .equals(.destructor))
    }

    pr = parse("fun f() {}", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let decl = pr.value as? FunDecl {
      assertThat(decl.body, .isInstance(of: BraceStmt.self))
    }

    pr = parse("static mutating fun f()", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let decl = pr.value as? FunDecl {
      assertThat(decl.modifiers, .count(2))
      assertThat(decl.modifiers, .contains { $0.kind == .static })
      assertThat(decl.modifiers, .contains { $0.kind == .mutating })
    }

    pr = parse("@inline @air_name(print) fun print()", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let decl = pr.value as? FunDecl {
      assertThat(decl.name, .equals("print"))
      assertThat(decl.attrs, .count(2))
      assertThat(decl.attrs, .contains { $0.name == "@inline" })
      assertThat(decl.attrs, .contains { $0.name == "@air_name" })
    }

    let source = "@inline @air_name(print) static mutating fun f ( )"
      .split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
  }

  func testParseParamDecl() {
    var pr: ParseResult<ASTNode?>

    pr = parse("fun f(a: Int, _ b: Int, c d: Int) {}", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let decl = pr.value as? FunDecl {
      assertThat(decl.params, .count(3))
      if decl.params.count > 2 {
        assertThat(decl.params[0].label, .equals("a"))
        assertThat(decl.params[0].name, .equals("a"))
        assertThat(decl.params[0].sign, .not(.isNil))

        assertThat(decl.params[1].label, .isNil)
        assertThat(decl.params[1].name, .equals("b"))
        assertThat(decl.params[1].sign, .not(.isNil))

        assertThat(decl.params[2].label, .equals("c"))
        assertThat(decl.params[2].name, .equals("d"))
        assertThat(decl.params[2].sign, .not(.isNil))
      }
    }

    pr = parse("fun f(a: Int = 0)", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let decl = pr.value as? FunDecl {
      assertThat(decl.params, .count(1))
      if decl.params.count > 0 {
        assertThat(decl.params[0].defaultValue, .isInstance(of: Expr.self))
      }
    }

    pr = parse("fun f() -> Int", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let decl = pr.value as? FunDecl {
      assertThat(decl.codom, .isInstance(of: QualTypeSign.self))
    }

    pr = parse("fun f<T>()", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let decl = pr.value as? FunDecl {
      assertThat(decl.genericParams, .count(1))
      assertThat(decl.genericParams, .contains { $0.name == "T" })
    }

    let source = "fun f < T , > ( _ x : Int , ) -> Int { }"
      .split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
  }

  func testParseInterfaceDecl() {
    var pr: ParseResult<ASTNode?>

    pr = parse("interface Foo {}", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: InterfaceDecl.self))
    if let decl = pr.value as? InterfaceDecl {
      assertThat(decl.name, .equals("Foo"))
      assertThat(decl.genericParams, .isEmpty)
    }

    pr = parse("interface Foo<T> {}", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: InterfaceDecl.self))
    if let decl = pr.value as? InterfaceDecl {
      assertThat(decl.genericParams, .count(1))
      assertThat(decl.genericParams, .contains { $0.name == "T" })
    }

    pr = parse(
      """
      interface Foo {
        let x
        fun f()
      }
      """,
      with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: InterfaceDecl.self))
    if let decl = pr.value as? InterfaceDecl {
      assertThat(decl.body, .isInstance(of: BraceStmt.self))
      if let body = decl.body {
        assertThat(body.stmts, .count(2))
        if body.stmts.count > 1 {
          assertThat(body.stmts[1], .isInstance(of: FunDecl.self))
          if let method = body.stmts[0] as? FunDecl {
            assertThat(method.kind, .equals(.method))
          }
        }
      }
    }

    let source =
      """
      interface Foo < T , > {
        static mutating let x : Int <- 42
        static mutating fun f < T , > ( _ x : Int , ) -> Int { }
      }
      """.split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: InterfaceDecl.self))
  }

  func testParseStructDecl() {
    var pr: ParseResult<ASTNode?>

    pr = parse("struct Foo {}", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: StructDecl.self))
    if let decl = pr.value as? StructDecl {
      assertThat(decl.name, .equals("Foo"))
      assertThat(decl.genericParams, .isEmpty)
    }

    pr = parse("struct Foo<T> {}", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: StructDecl.self))
    if let decl = pr.value as? StructDecl {
      assertThat(decl.genericParams, .count(1))
      assertThat(decl.genericParams, .contains { $0.name == "T" })
    }

    pr = parse(
      """
      struct Foo {
        let x
        fun f()
      }
      """,
      with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: StructDecl.self))
    if let decl = pr.value as? StructDecl {
      assertThat(decl.body, .isInstance(of: BraceStmt.self))
      if let body = decl.body {
        assertThat(body.stmts, .count(2))
        if body.stmts.count > 1 {
          assertThat(body.stmts[1], .isInstance(of: FunDecl.self))
          if let method = body.stmts[0] as? FunDecl {
            assertThat(method.kind, .equals(.method))
          }
        }
      }
    }

    let source =
      """
      struct Foo < T , > {
        static mutating let x : Int <- 42
        static mutating fun f < T , > ( _ x : Int , ) -> Int { }
      }
      """.split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: StructDecl.self))
  }

  func testParseUnionDecl() {
    var pr: ParseResult<ASTNode?>

    pr = parse("union Foo {}", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: UnionDecl.self))
    if let decl = pr.value as? UnionDecl {
      assertThat(decl.name, .equals("Foo"))
      assertThat(decl.genericParams, .isEmpty)
    }

    pr = parse("union Foo<T> {}", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: UnionDecl.self))
    if let decl = pr.value as? UnionDecl {
      assertThat(decl.genericParams, .count(1))
      assertThat(decl.genericParams, .contains { $0.name == "T" })
    }

    pr = parse(
      """
      union Foo {
        case struct A {}
        let x
        fun f()
      }
      """,
      with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: UnionDecl.self))
    if let decl = pr.value as? UnionDecl {
      assertThat(decl.body, .isInstance(of: BraceStmt.self))
      if let body = decl.body {
        assertThat(body.stmts, .count(3))
        if body.stmts.count > 2 {
          assertThat(body.stmts[0], .isInstance(of: UnionTypeCaseDecl.self))
          assertThat(body.stmts[2], .isInstance(of: FunDecl.self))
          if let method = body.stmts[0] as? FunDecl {
            assertThat(method.kind, .equals(.method))
          }
        }
      }
    }

    let source =
      """
      union Foo < T , > {
        case struct A { }
        static mutating let x : Int <- 42
        static mutating fun f < T , > ( _ x : Int , ) -> Int { }
      }
      """.split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: UnionDecl.self))
  }

  func testParseTypeExtDecl() {
    var pr: ParseResult<ASTNode?>

    pr = parse("extension Foo<T=Bar> {}", with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: TypeExtDecl.self))
    if let decl = pr.value as? TypeExtDecl {
      assertThat(decl.extTypeSign, .isInstance(of: IdentSign.self))
    }

    pr = parse(
      """
      extension Foo {
        let x
        fun f()
      }
      """,
      with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: TypeExtDecl.self))
    if let decl = pr.value as? TypeExtDecl {
      assertThat(decl.body, .isInstance(of: BraceStmt.self))
      if let body = decl.body as? BraceStmt {
        assertThat(body.stmts, .count(2))
        if body.stmts.count > 1 {
          assertThat(body.stmts[1], .isInstance(of: FunDecl.self))
          if let method = body.stmts[0] as? FunDecl {
            assertThat(method.kind, .equals(.method))
          }
        }
      }
    }

    let source =
      """
      extension Foo < T = Bar , > {
        static mutating let x : Int <- 42
        static mutating fun f < T , > ( _ x : Int , ) -> Int { }
      }
      """.split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseDecl)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: TypeExtDecl.self))
  }

}
