import XCTest

import AST
@testable import Parser

class ExprParserTests: XCTestCase, ParserTestCase {

  func testParseNullExpr() {
    var pr: Parser.Result<Expr?>

    pr = parse("nullref", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: NullExpr.self))
  }

  func testParseBoolLitExpr() {
    var pr: Parser.Result<Expr?>

    pr = parse("true", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: BoolLitExpr.self))
    assertThat((pr.value as? BoolLitExpr)?.value, .equals(true))

    pr = parse("false", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: BoolLitExpr.self))
    assertThat((pr.value as? BoolLitExpr)?.value, .equals(false))
  }

  func testParseIntLitExpr() {
    var pr: Parser.Result<Expr?>

    pr = parse("42", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: IntLitExpr.self))
    assertThat((pr.value as? IntLitExpr)?.value, .equals(42))
  }

  func testParseFloatLitExpr() {
    var pr: Parser.Result<Expr?>

    pr = parse("4.2", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: FloatLitExpr.self))
    assertThat((pr.value as? FloatLitExpr)?.value, .equals(4.2))
  }

  func testParseStrLitExpr() {
    var pr: Parser.Result<Expr?>

    pr = parse("\"Hello, World!\"", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: StrLitExpr.self))
    assertThat((pr.value as? StrLitExpr)?.value, .equals("\"Hello, World!\""))
  }

  func testParsePrefixExpr() {
    var pr: Parser.Result<Expr?>

    pr = parse("+1", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: PrefixExpr.self))
    if let expression = pr.value as? PrefixExpr {
      assertThat(expression.op.name, .equals("+"))
      assertThat(expression.operand, .isInstance(of: IntLitExpr.self))
    }
  }

  func testUnsafeCastExpr() {
    var pr: Parser.Result<Expr?>

    pr = parse("a as Int", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: UnsafeCastExpr.self))

    let source = "a as Int".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: UnsafeCastExpr.self))
  }

  func testInfixExpr() {
    var pr: Parser.Result<Expr?>

    pr = parse("a + b", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: InfixExpr.self))

    pr = parse("a + b * c", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: InfixExpr.self))
    if let expression = pr.value as? InfixExpr {
      assertThat(expression.op.name, .equals("+"))
      assertThat(expression.lhs, .isInstance(of: IdentExpr.self))
      assertThat(expression.rhs, .isInstance(of: InfixExpr.self))
    }

    pr = parse("a * b + c", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: InfixExpr.self))
    if let expression = pr.value as? InfixExpr {
      assertThat(expression.op.name, .equals("+"))
      assertThat(expression.lhs, .isInstance(of: InfixExpr.self))
      assertThat(expression.rhs, .isInstance(of: IdentExpr.self))
    }

    let source = "a + b + c".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: InfixExpr.self))
  }

  func testParseIdentExpr() {
    var pr: Parser.Result<Expr?>

    pr = parse("x", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: IdentExpr.self))
    if let ident = pr.value as? IdentExpr {
      assertThat(ident.name, .equals("x"))
      assertThat(ident.specArgs, .isEmpty)
    }

    pr = parse("Map<Key=String, Value=Int>", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: IdentExpr.self))
    if let ident = pr.value as? IdentExpr {
      assertThat(ident.name, .equals("Map"))
      assertThat(ident.specArgs, .count(2))
      assertThat(ident.specArgs.keys, .contains("Key"))
      assertThat(ident.specArgs.keys, .contains("Value"))
    }

    let source = "Map < Key = String , Value = Int , >"
      .split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: IdentExpr.self))
  }

  func testParseLambdaExpr() {
    var pr: Parser.Result<Expr?>

    pr = parse("fun {}", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: LambdaExpr.self))
    if let lambda = pr.value as? LambdaExpr {
      assertThat(lambda.params, .isEmpty)
      assertThat(lambda.codom, .isNil)
    }

    pr = parse("fun (a: Int, _ b: Int, c d: Int) {}", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: LambdaExpr.self))
    if let lambda = pr.value as? LambdaExpr {
      assertThat(lambda.params, .count(3))
      if lambda.params.count > 2 {
        assertThat(lambda.params[0].label, .equals("a"))
        assertThat(lambda.params[0].name, .equals("a"))
        assertThat(lambda.params[0].sign, .not(.isNil))

        assertThat(lambda.params[1].label, .isNil)
        assertThat(lambda.params[1].name, .equals("b"))
        assertThat(lambda.params[1].sign, .not(.isNil))

        assertThat(lambda.params[2].label, .equals("c"))
        assertThat(lambda.params[2].name, .equals("d"))
        assertThat(lambda.params[2].sign, .not(.isNil))
      }

      assertThat(lambda.codom, .isNil)
    }

    pr = parse("fun -> Int {}", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: LambdaExpr.self))
    if let lambda = pr.value as? LambdaExpr {
      assertThat(lambda.params, .isEmpty)
      assertThat(lambda.codom, .not(.isNil))
    }

    pr = parse("fun (_ x: Int) -> Int {}", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: LambdaExpr.self))
    if let lambda = pr.value as? LambdaExpr {
      assertThat(lambda.params, .count(1))
      assertThat(lambda.codom, .not(.isNil))
    }

    let source = "fun ( _ x: Int , ) -> Int { }".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: LambdaExpr.self))
  }

  func testParseArrayLitExpr() {
    var pr: Parser.Result<Expr?>

    pr = parse("[]", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: ArrayLitExpr.self))
    if let literal = pr.value as? ArrayLitExpr {
      assertThat(literal.elems, .isEmpty)
    }

    pr = parse("[ a ]", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: ArrayLitExpr.self))
    if let literal = pr.value as? ArrayLitExpr {
      assertThat(literal.elems, .count(1))
      for element in literal.elems {
        assertThat(element, .isInstance(of: IdentExpr.self))
      }
    }

    pr = parse("[ a, b, c ]", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: ArrayLitExpr.self))
    if let literal = pr.value as? ArrayLitExpr {
      assertThat(literal.elems, .count(3))
      for element in literal.elems {
        assertThat(element, .isInstance(of: IdentExpr.self))
      }
    }

    let source = "[ a , b , c , ]".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
  }

  func testParseSetExor() {
    var pr: Parser.Result<Expr?>

    pr = parse("{}", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: SetLitExpr.self))
    if let literal = pr.value as? SetLitExpr {
      assertThat(literal.elems, .isEmpty)
    }

    pr = parse("{ a }", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: SetLitExpr.self))
    if let literal = pr.value as? SetLitExpr {
      assertThat(literal.elems, .count(1))
      for element in literal.elems {
        assertThat(element, .isInstance(of: IdentExpr.self))
      }
    }

    pr = parse("{ a, b, c }", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: SetLitExpr.self))
    if let literal = pr.value as? SetLitExpr {
      assertThat(literal.elems, .count(3))
      for element in literal.elems {
        assertThat(element, .isInstance(of: IdentExpr.self))
      }
    }

    let source = "{ a , b , c , }".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: SetLitExpr.self))
  }

  func testParseMapExpr() {
    var pr: Parser.Result<Expr?>

    pr = parse("{:}", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: MapLitExpr.self))
    if let literal = pr.value as? MapLitExpr {
      assertThat(literal.elems, .isEmpty)
    }

    pr = parse("{ a: 1 }", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: MapLitExpr.self))
    if let literal = pr.value as? MapLitExpr {
      assertThat(literal.elems, .count(1))
      assertThat(literal.elems[0].key, .isInstance(of: IdentExpr.self))
      assertThat(literal.elems[0].value, .isInstance(of: IntLitExpr.self))
    }

    pr = parse("{ a: 1, b: 2, c: 3 }", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: MapLitExpr.self))
    if let literal = pr.value as? MapLitExpr {
      assertThat(literal.elems, .count(3))
      for i in 0 ..< 3 {
        assertThat(literal.elems[i].key, .isInstance(of: IdentExpr.self))
        assertThat(literal.elems[i].value, .isInstance(of: IntLitExpr.self))
      }
    }

    let source = "{ a : 1 , b : 2 , c : 3 , }".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: MapLitExpr.self))
  }

  func testParseImplicitSelectExpr() {
    var pr: Parser.Result<Expr?>

    pr = parse(".a", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: ImplicitSelectExpr.self))
    if let select = pr.value as? ImplicitSelectExpr {
      assertThat(select.ownee.name, .equals("a"))
    }

    pr = parse(".+", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: ImplicitSelectExpr.self))
    if let select = pr.value as? ImplicitSelectExpr {
      assertThat(select.ownee.name, .equals("+"))
    }
  }

  func testParseSelectExpr() {
    var pr: Parser.Result<Expr?>

    pr = parse("a.a", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: SelectExpr.self))
    if let select = pr.value as? SelectExpr {
      assertThat(select.owner, .isInstance(of: IdentExpr.self))
      assertThat(select.ownee.name, .equals("a"))
    }

    pr = parse("a.+", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: SelectExpr.self))
    if let select = pr.value as? SelectExpr {
      assertThat(select.owner, .isInstance(of: IdentExpr.self))
      assertThat(select.ownee.name, .equals("+"))
    }

    let source = "a .+".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: SelectExpr.self))
  }

  func testParseCallExpr() {
    var pr: Parser.Result<Expr?>

    pr = parse("f()", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: CallExpr.self))
    if let call = pr.value as? CallExpr {
      assertThat(call.callee, .isInstance(of: IdentExpr.self))
      assertThat(call.args, .isEmpty)
    }

    pr = parse("f()()", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: CallExpr.self))
    if let call = pr.value as? CallExpr {
      assertThat(call.callee, .isInstance(of: CallExpr.self))
    }

    pr = parse("f(x)", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: CallExpr.self))
    if let call = pr.value as? CallExpr {
      assertThat(call.callee, .isInstance(of: IdentExpr.self))
      assertThat(call.args, .count(1))
      if call.args.count > 0 {
        assertThat(call.args[0].label, .isNil)
        assertThat(call.args[0].op.name, .equals(":="))
        assertThat(call.args[0].value, .isInstance(of: IdentExpr.self))
      }
    }

    pr = parse("f(a := x)", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: CallExpr.self))
    if let call = pr.value as? CallExpr {
      assertThat(call.callee, .isInstance(of: IdentExpr.self))
      assertThat(call.args, .count(1))
      if call.args.count > 0 {
        assertThat(call.args[0].label, .equals("a"))
        assertThat(call.args[0].op.name, .equals(":="))
        assertThat(call.args[0].value, .isInstance(of: IdentExpr.self))
      }
    }

    pr = parse("f(x, b := y)", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: CallExpr.self))
    if let call = pr.value as? CallExpr {
      assertThat(call.callee, .isInstance(of: IdentExpr.self))
      assertThat(call.args, .count(2))
      if call.args.count > 0 {
        assertThat(call.args[0].label, .isNil)
        assertThat(call.args[0].op.name, .equals(":="))
        assertThat(call.args[0].value, .isInstance(of: IdentExpr.self))
      }

      if call.args.count > 1 {
        assertThat(call.args[1].label, .equals("b"))
        assertThat(call.args[1].op.name, .equals(":="))
        assertThat(call.args[1].value, .isInstance(of: IdentExpr.self))
      }
    }

    let source = "f( x , b := y , )".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: CallExpr.self))
  }

  func testParseSubscriptExpr() {
    var pr: Parser.Result<Expr?>

    pr = parse("f[]", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: CallExpr.self))
    if let call = pr.value as? CallExpr {
      assertThat(call.callee, .isInstance(of: SelectExpr.self))
      if let select = call.callee as? SelectExpr {
        assertThat(select.owner, .isInstance(of: IdentExpr.self))
        if let owner = select.owner as? IdentExpr {
          assertThat(owner.name, .equals("f"))
        }
        assertThat(select.ownee.name, .equals("[]"))
      }
      assertThat(call.args, .isEmpty)
    }

    pr = parse("f[][]", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: CallExpr.self))
    if let call = pr.value as? CallExpr {
      assertThat(call.callee, .isInstance(of: SelectExpr.self))
      if let select = call.callee as? SelectExpr {
        assertThat(select.owner, .isInstance(of: CallExpr.self))
        assertThat(select.ownee.name, .equals("[]"))
      }
    }

    pr = parse("f[x]", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: CallExpr.self))
    if let call = pr.value as? CallExpr {
      assertThat(call.callee, .isInstance(of: SelectExpr.self))
      assertThat(call.args, .count(1))
      if call.args.count > 0 {
        assertThat(call.args[0].label, .isNil)
        assertThat(call.args[0].op.name, .equals(":="))
        assertThat(call.args[0].value, .isInstance(of: IdentExpr.self))
      }
    }

    pr = parse("f[a := x]", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: CallExpr.self))
    if let call = pr.value as? CallExpr {
      assertThat(call.callee, .isInstance(of: SelectExpr.self))
      assertThat(call.args, .count(1))
      if call.args.count > 0 {
        assertThat(call.args[0].label, .equals("a"))
        assertThat(call.args[0].op.name, .equals(":="))
        assertThat(call.args[0].value, .isInstance(of: IdentExpr.self))
      }
    }

    pr = parse("f[x, b := y]", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: CallExpr.self))
    if let call = pr.value as? CallExpr {
      assertThat(call.callee, .isInstance(of: SelectExpr.self))
      assertThat(call.args, .count(2))
      if call.args.count > 0 {
        assertThat(call.args[0].label, .isNil)
        assertThat(call.args[0].op.name, .equals(":="))
        assertThat(call.args[0].value, .isInstance(of: IdentExpr.self))
      }

      if call.args.count > 1 {
        assertThat(call.args[1].label, .equals("b"))
        assertThat(call.args[1].op.name, .equals(":="))
        assertThat(call.args[1].value, .isInstance(of: IdentExpr.self))
      }
    }

    let source = "f[ x , b := y , ]".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: CallExpr.self))
  }

  func testParseParenExpr() {
    var pr: Parser.Result<Expr?>

    pr = parse("(a)", with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: ParenExpr.self))
    if let enclosing = pr.value as? ParenExpr {
      assertThat(enclosing.expr, .isInstance(of: IdentExpr.self))
    }

    let source = "( a )".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpr)
    assertThat(pr.issues, .isEmpty)
    assertThat(pr.value, .isInstance(of: ParenExpr.self))
    if let enclosing = pr.value as? ParenExpr {
      assertThat(enclosing.expr, .isInstance(of: IdentExpr.self))
    }
  }

}
