import XCTest

import AST
@testable import Parser

class StatementParserTests: XCTestCase, ParserTestCase {

  func testParsePropertyDeclaration() {
    var pr: Parser.Result<Node?>

    pr = parse("let x", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: PropDecl.self))
    if let declaration = pr.value as? PropDecl {
      assertThat(declaration.name, .equals("x"))
      assertThat(declaration.attributes, .isEmpty)
      assertThat(declaration.typeAnnotation, .isNil)
      assertThat(declaration.initialBinding, .isNil)
    }

    pr = parse("var x", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: PropDecl.self))
    if let declaration = pr.value as? PropDecl {
      assertThat(declaration.attributes, .equals([.reassignable]))
    }

    pr = parse("let x: @mut Int", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: PropDecl.self))
    if let declaration = pr.value as? PropDecl {
      assertThat(declaration.typeAnnotation, .isInstance(of: QualTypeSign.self))
    }

    pr = parse("let x <- 42", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: PropDecl.self))
    if let declaration = pr.value as? PropDecl {
      assertThat(declaration.initialBinding?.op, .equals(.move))
      assertThat(declaration.initialBinding?.value, .isInstance(of: Expr.self))
    }

    pr = parse("let x: @mut Int <- 42", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: PropDecl.self))
    if let declaration = pr.value as? PropDecl {
      assertThat(declaration.typeAnnotation, .isInstance(of: QualTypeSign.self))
      assertThat(declaration.initialBinding?.op, .equals(.move))
      assertThat(declaration.initialBinding?.value, .isInstance(of: Expr.self))
    }

    pr = parse("static mutating let x: Int <- 42", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: PropDecl.self))
    if let declaration = pr.value as? PropDecl {
      assertThat(declaration.attributes, .equals([.mutating, .static]))
    }

    let source = "static mutating let x : Int <- 42".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: PropDecl.self))
  }

  func testParseFunctionDeclaration() {
    var pr: Parser.Result<Node?>

    pr = parse("fun f()", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let declaration = pr.value as? FunDecl {
      assertThat(declaration.name, .equals("f"))
      assertThat(declaration.attributes, .isEmpty)
      assertThat(declaration.kind, .equals(.regular))
      assertThat(declaration.placeholders, .isEmpty)
      assertThat(declaration.parameters, .isEmpty)
      assertThat(declaration.codomain, .isNil)
    }

    pr = parse("fun + ()", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let declaration = pr.value as? FunDecl {
      assertThat(declaration.name, .equals("+"))
    }

    pr = parse("new()", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let declaration = pr.value as? FunDecl {
      assertThat(declaration.name, .equals("new"))
      assertThat(declaration.kind, .equals(.constructor))
    }

    pr = parse("del()", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let declaration = pr.value as? FunDecl {
      assertThat(declaration.name, .equals("del"))
      assertThat(declaration.kind, .equals(.destructor))
    }

    pr = parse("fun f(a: Int, _ b: Int, c d: Int) {}", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let declaration = pr.value as? FunDecl {
      assertThat(declaration.parameters, .count(3))
      if declaration.parameters.count > 2 {
        assertThat(declaration.parameters[0].label, .equals("a"))
        assertThat(declaration.parameters[0].name, .equals("a"))
        assertThat(declaration.parameters[0].typeAnnotation, .not(.isNil))

        assertThat(declaration.parameters[1].label, .isNil)
        assertThat(declaration.parameters[1].name, .equals("b"))
        assertThat(declaration.parameters[1].typeAnnotation, .not(.isNil))

        assertThat(declaration.parameters[2].label, .equals("c"))
        assertThat(declaration.parameters[2].name, .equals("d"))
        assertThat(declaration.parameters[2].typeAnnotation, .not(.isNil))
      }
    }

    pr = parse("fun f(a: Int = 0)", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let declaration = pr.value as? FunDecl {
      assertThat(declaration.parameters, .count(1))
      if declaration.parameters.count > 0 {
        assertThat(declaration.parameters[0].defaultValue, .isInstance(of: Expr.self))
      }
    }

    pr = parse("fun f<T>()", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let declaration = pr.value as? FunDecl {
      assertThat(declaration.placeholders, .count(1))
      assertThat(declaration.placeholders, .contains("T"))
    }

    pr = parse("fun f() -> Int", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let declaration = pr.value as? FunDecl {
      assertThat(declaration.codomain, .isInstance(of: QualTypeSign.self))
    }

    pr = parse("fun f() {}", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let declaration = pr.value as? FunDecl {
      assertThat(declaration.body, .isInstance(of: Block.self))
    }

    pr = parse("static mutating fun f()", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
    if let declaration = pr.value as? FunDecl {
      assertThat(declaration.attributes, .equals([.mutating, .static]))
    }

    let source = "static mutating fun f < T , > ( _ x : Int , ) -> Int { }"
      .split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: FunDecl.self))
  }

  func testParseStructDeclaration() {
    var pr: Parser.Result<Node?>

    pr = parse("struct Foo {}", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: StructDecl.self))
    if let declaration = pr.value as? StructDecl {
      assertThat(declaration.name, .equals("Foo"))
      assertThat(declaration.placeholders, .isEmpty)
    }

    pr = parse("struct Foo<T> {}", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: StructDecl.self))
    if let declaration = pr.value as? StructDecl {
      assertThat(declaration.placeholders, .count(1))
      assertThat(declaration.placeholders, .contains("T"))
    }

    pr = parse(
      """
      struct Foo {
        let x
        fun f()
      }
      """,
      with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: StructDecl.self))
    if let declaration = pr.value as? StructDecl {
      assertThat(declaration.body.statements, .count(2))
      if declaration.body.statements.count > 1 {
        assertThat(declaration.body.statements[0], .isInstance(of: PropDecl.self))
        assertThat(declaration.body.statements[1], .isInstance(of: FunDecl.self))
        if let method = declaration.body.statements[0] as? FunDecl {
          assertThat(method.kind, .equals(.method))
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
    pr = parse(source, with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: StructDecl.self))
  }

  func testParseInterfaceDeclaration() {
    var pr: Parser.Result<Node?>

    pr = parse("interface Foo {}", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: InterfaceDecl.self))
    if let declaration = pr.value as? InterfaceDecl {
      assertThat(declaration.name, .equals("Foo"))
      assertThat(declaration.placeholders, .isEmpty)
    }

    pr = parse("interface Foo<T> {}", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: InterfaceDecl.self))
    if let declaration = pr.value as? InterfaceDecl {
      assertThat(declaration.placeholders, .count(1))
      assertThat(declaration.placeholders, .contains("T"))
    }

    pr = parse(
      """
      interface Foo {
        let x
        fun f()
      }
      """,
      with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: InterfaceDecl.self))
    if let declaration = pr.value as? InterfaceDecl {
      assertThat(declaration.body.statements, .count(2))
      if declaration.body.statements.count > 1 {
        assertThat(declaration.body.statements[0], .isInstance(of: PropDecl.self))
        assertThat(declaration.body.statements[1], .isInstance(of: FunDecl.self))
        if let method = declaration.body.statements[0] as? FunDecl {
          assertThat(method.kind, .equals(.method))
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
    pr = parse(source, with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: InterfaceDecl.self))
  }

  func testParseWhileLoop() {
    var pr: Parser.Result<Node?>

    pr = parse("while c1 {}", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: WhileLoop.self))

    let source = "while c1 { }".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: WhileLoop.self))
  }

  func testParseReturn() {
    var pr: Parser.Result<Node?>

    pr = parse("return", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: ReturnStmt.self))
    if let statement = pr.value as? ReturnStmt {
      assertThat(statement.binding, .isNil)
    }

    pr = parse("return <- 42", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: ReturnStmt.self))
    if let statement = pr.value as? ReturnStmt {
      assertThat(statement.binding?.op, .equals(.move))
      assertThat(statement.binding?.value, .isInstance(of: Expr.self))
    }

    let source = "return <- 42".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: ReturnStmt.self))
  }

  func testParseBinding() {
    var pr: Parser.Result<Node?>

    pr = parse("f().x := v[a &- b]", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: BindingStmt.self))
    if let statement = pr.value as? BindingStmt {
      assertThat(statement.op, .equals(.copy))
    }

    pr = parse("f().x &- v[a &- b]", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: BindingStmt.self))
    if let statement = pr.value as? BindingStmt {
      assertThat(statement.op, .equals(.ref))
    }

    pr = parse("f().x <- v[a &- b]", with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: BindingStmt.self))
    if let statement = pr.value as? BindingStmt {
      assertThat(statement.op, .equals(.move))
    }

    let source = "f( ) .x <- v [ a &- b , ]".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseStatement)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: BindingStmt.self))
  }

}
