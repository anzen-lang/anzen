import XCTest

import AST
@testable import Parser

class ExpressionParserTests: XCTestCase, ParserTestCase {

  func testParseIntegerLiteral() {
    var pr: Parser.Result<Expr?>

    pr = parse("42", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: Literal<Int>.self))
    assertThat((pr.value as? Literal<Int>)?.value, .equals(42))
  }

  func testParseFloatingPointLiteral() {
    var pr: Parser.Result<Expr?>

    pr = parse("4.2", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: Literal<Double>.self))
    assertThat((pr.value as? Literal<Double>)?.value, .equals(4.2))
  }

  func testParseStringLiteral() {
    var pr: Parser.Result<Expr?>

    pr = parse("\"Hello, World!\"", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: Literal<String>.self))
    assertThat((pr.value as? Literal<String>)?.value, .equals("Hello, World!"))
  }

  func testParseBoolLiteral() {
    var pr: Parser.Result<Expr?>

    pr = parse("true", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: Literal<Bool>.self))
    assertThat((pr.value as? Literal<Bool>)?.value, .equals(true))

    pr = parse("false", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: Literal<Bool>.self))
    assertThat((pr.value as? Literal<Bool>)?.value, .equals(false))
  }

  func testParseUnaryExpression() {
    var pr: Parser.Result<Expr?>

    pr = parse("+1", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: UnExpr.self))
    if let expression = pr.value as? UnExpr {
      assertThat(expression.op, .equals(.add))
      assertThat(expression.operand, .isInstance(of: Literal<Int>.self))
    }
  }

  func testCastExpression() {
    var pr: Parser.Result<Expr?>

    pr = parse("a as Int", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: CastExpr.self))

    pr = parse("a as Int as Any", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: CastExpr.self))
    if let expression = pr.value as? CastExpr {
      assertThat(expression.castType, .isInstance(of: TypeIdent.self))
      if let typeIdentifier = expression.castType as? TypeIdent {
        assertThat(typeIdentifier.name, .equals("Any"))
      }
    }

    let source = "a as Int".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: CastExpr.self))
  }

  func testBinaryExpression() {
    var pr: Parser.Result<Expr?>

    pr = parse("a + b", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: BinExpr.self))

    pr = parse("a + b * c", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: BinExpr.self))
    if let expression = pr.value as? BinExpr {
      assertThat(expression.right, .isInstance(of: BinExpr.self))
    }

    pr = parse("a * b + c", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: BinExpr.self))
    if let expression = pr.value as? BinExpr {
      assertThat(expression.right, .isInstance(of: Ident.self))
    }

    let source = "a + b".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: BinExpr.self))
  }

  func testParseIdentifier() {
    var pr: Parser.Result<Expr?>

    pr = parse("x", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: Ident.self))
    if let identifier = pr.value as? Ident {
      assertThat(identifier.name, .equals("x"))
    }

    pr = parse("Map<Key=String, Value=Int>", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: Ident.self))
    if let identifier = pr.value as? Ident {
      assertThat(identifier.name, .equals("Map"))
      assertThat(identifier.specializations, .count(2))
      assertThat(identifier.specializations.keys, .contains("Key"))
      assertThat(identifier.specializations.keys, .contains("Value"))
    }

    let source = "Map < Key = String , Value = Int , >"
      .split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: Ident.self))
  }

  func testParseIfExpression() {
    var pr: Parser.Result<Expr?>

    pr = parse("if c1 {}", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: IfExpr.self))
    if let conditional = pr.value as? IfExpr {
      assertThat(conditional.elseBlock, .isNil)
    }

    pr = parse("if c1 {} else {}", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: IfExpr.self))
    if let conditional = pr.value as? IfExpr {
      assertThat(conditional.elseBlock, .isInstance(of: Block.self))
    }

    pr = parse("if c1 {} else if c2 {}", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: IfExpr.self))
    if let conditional = pr.value as? IfExpr {
      assertThat(conditional.elseBlock, .isInstance(of: IfExpr.self))
    }

    let source = "if c1 { } else if c2 { }".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: IfExpr.self))
  }

  func testParseLambda() {
    var pr: Parser.Result<Expr?>

    pr = parse("fun {}", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: LambdaExpr.self))
    if let lambda = pr.value as? LambdaExpr {
      assertThat(lambda.parameters, .isEmpty)
      assertThat(lambda.codomain, .isNil)
    }

    pr = parse("fun (a: Int, _ b: Int, c d: Int) {}", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: LambdaExpr.self))
    if let lambda = pr.value as? LambdaExpr {
      assertThat(lambda.parameters, .count(3))
      if lambda.parameters.count > 0 {
        assertThat(lambda.parameters[0].label, .equals("a"))
        assertThat(lambda.parameters[0].name, .equals("a"))
        assertThat(lambda.parameters[0].typeAnnotation, .not(.isNil))
      }

      if lambda.parameters.count > 1 {
        assertThat(lambda.parameters[1].label, .isNil)
        assertThat(lambda.parameters[1].name, .equals("b"))
        assertThat(lambda.parameters[1].typeAnnotation, .not(.isNil))
      }

      if lambda.parameters.count > 2 {
        assertThat(lambda.parameters[2].label, .equals("c"))
        assertThat(lambda.parameters[2].name, .equals("d"))
        assertThat(lambda.parameters[2].typeAnnotation, .not(.isNil))
      }

      assertThat(lambda.codomain, .isNil)
    }

    pr = parse("fun -> Int {}", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: LambdaExpr.self))
    if let lambda = pr.value as? LambdaExpr {
      assertThat(lambda.parameters, .isEmpty)
      assertThat(lambda.codomain, .not(.isNil))
    }

    pr = parse("fun (_ x: Int) -> Int {}", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: LambdaExpr.self))
    if let lambda = pr.value as? LambdaExpr {
      assertThat(lambda.parameters, .count(1))
      assertThat(lambda.codomain, .not(.isNil))
    }

    let source = "fun ( _ x: Int , ) -> Int { }".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: LambdaExpr.self))
  }

  func testParseArrayLiteral() {
    var pr: Parser.Result<Expr?>

    pr = parse("[]", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: ArrayLiteral.self))
    if let literal = pr.value as? ArrayLiteral {
      assertThat(literal.elements, .isEmpty)
    }

    pr = parse("[ a ]", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: ArrayLiteral.self))
    if let literal = pr.value as? ArrayLiteral {
      assertThat(literal.elements, .count(1))
      for element in literal.elements {
        assertThat(element, .isInstance(of: Ident.self))
      }
    }

    pr = parse("[ a, b, c ]", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: ArrayLiteral.self))
    if let literal = pr.value as? ArrayLiteral {
      assertThat(literal.elements, .count(3))
      for element in literal.elements {
        assertThat(element, .isInstance(of: Ident.self))
      }
    }

    let source = "[ a , b , c , ]".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: ArrayLiteral.self))
  }

  func testParseSetLiteral() {
    var pr: Parser.Result<Expr?>

    pr = parse("{}", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: SetLiteral.self))
    if let literal = pr.value as? SetLiteral {
      assertThat(literal.elements, .isEmpty)
    }

    pr = parse("{ a }", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: SetLiteral.self))
    if let literal = pr.value as? SetLiteral {
      assertThat(literal.elements, .count(1))
      for element in literal.elements {
        assertThat(element, .isInstance(of: Ident.self))
      }
    }

    pr = parse("{ a, b, c }", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: SetLiteral.self))
    if let literal = pr.value as? SetLiteral {
      assertThat(literal.elements, .count(3))
      for element in literal.elements {
        assertThat(element, .isInstance(of: Ident.self))
      }
    }

    let source = "{ a , b , c , }".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: SetLiteral.self))
  }

  func testParseMapLiteral() {
    var pr: Parser.Result<Expr?>

    pr = parse("{:}", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: MapLiteral.self))
    if let literal = pr.value as? MapLiteral {
      assertThat(literal.elements, .isEmpty)
    }

    pr = parse("{ a: 1 }", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: MapLiteral.self))
    if let literal = pr.value as? MapLiteral {
      assertThat(literal.elements, .count(1))
      assertThat(literal.elements["a"], .isInstance(of: Literal<Int>.self))
    }

    pr = parse("{ a: 1, b: 2, c: 3 }", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: MapLiteral.self))
    if let literal = pr.value as? MapLiteral {
      assertThat(literal.elements, .count(3))
      assertThat(literal.elements["a"], .isInstance(of: Literal<Int>.self))
      assertThat(literal.elements["b"], .isInstance(of: Literal<Int>.self))
      assertThat(literal.elements["c"], .isInstance(of: Literal<Int>.self))
    }

    let source = "{ a : 1 , b : 2 , c : 3 , }".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: MapLiteral.self))
  }

  func testParseImplicitSelect() {
    var pr: Parser.Result<Expr?>

    pr = parse(".a", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: SelectExpr.self))
    if let select = pr.value as? SelectExpr {
      assertThat(select.owner, .isNil)
      assertThat(select.ownee.name, .equals("a"))
    }

    pr = parse(".+", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: SelectExpr.self))
    if let select = pr.value as? SelectExpr {
      assertThat(select.owner, .isNil)
      assertThat(select.ownee.name, .equals("+"))
    }
  }

  func testParseSelect() {
    var pr: Parser.Result<Expr?>

    pr = parse("a.a", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: SelectExpr.self))
    if let select = pr.value as? SelectExpr {
      assertThat(select.owner, .isInstance(of: Ident.self))
      assertThat(select.ownee.name, .equals("a"))
    }

    pr = parse("a.+", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: SelectExpr.self))
    if let select = pr.value as? SelectExpr {
      assertThat(select.owner, .isInstance(of: Ident.self))
      assertThat(select.ownee.name, .equals("+"))
    }

    let source = "a .+".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: SelectExpr.self))
  }

  func testParseCall() {
    var pr: Parser.Result<Expr?>

    pr = parse("f()", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: CallExpr.self))
    if let call = pr.value as? CallExpr {
      assertThat(call.callee, .isInstance(of: Ident.self))
      assertThat(call.arguments, .isEmpty)
    }

    pr = parse("f()()", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: CallExpr.self))
    if let call = pr.value as? CallExpr {
      assertThat(call.callee, .isInstance(of: CallExpr.self))
    }

    pr = parse("f(x)", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: CallExpr.self))
    if let call = pr.value as? CallExpr {
      assertThat(call.callee, .isInstance(of: Ident.self))
      assertThat(call.arguments, .count(1))
      if call.arguments.count > 0 {
        assertThat(call.arguments[0].label, .isNil)
        assertThat(call.arguments[0].bindingOp, .equals(.copy))
        assertThat(call.arguments[0].value, .isInstance(of: Ident.self))
      }
    }

    pr = parse("f(a := x)", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: CallExpr.self))
    if let call = pr.value as? CallExpr {
      assertThat(call.callee, .isInstance(of: Ident.self))
      assertThat(call.arguments, .count(1))
      if call.arguments.count > 0 {
        assertThat(call.arguments[0].label, .equals("a"))
        assertThat(call.arguments[0].bindingOp, .equals(.copy))
        assertThat(call.arguments[0].value, .isInstance(of: Ident.self))
      }
    }

    pr = parse("f(x, b := y)", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: CallExpr.self))
    if let call = pr.value as? CallExpr {
      assertThat(call.callee, .isInstance(of: Ident.self))
      assertThat(call.arguments, .count(2))
      if call.arguments.count > 0 {
        assertThat(call.arguments[0].label, .isNil)
        assertThat(call.arguments[0].bindingOp, .equals(.copy))
        assertThat(call.arguments[0].value, .isInstance(of: Ident.self))
      }

      if call.arguments.count > 1 {
        assertThat(call.arguments[1].label, .equals("b"))
        assertThat(call.arguments[1].bindingOp, .equals(.copy))
        assertThat(call.arguments[1].value, .isInstance(of: Ident.self))
      }
    }

    let source = "f( x , b := y , )".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: CallExpr.self))
  }

  func testParseSubscript() {
    var pr: Parser.Result<Expr?>

    pr = parse("f[]", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: SubscriptExpr.self))
    if let call = pr.value as? SubscriptExpr {
      assertThat(call.callee, .isInstance(of: Ident.self))
      assertThat(call.arguments, .isEmpty)
    }

    pr = parse("f[][]", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: SubscriptExpr.self))
    if let call = pr.value as? CallExpr {
      assertThat(call.callee, .isInstance(of: SubscriptExpr.self))
    }

    pr = parse("f[x]", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: SubscriptExpr.self))
    if let call = pr.value as? SubscriptExpr {
      assertThat(call.callee, .isInstance(of: Ident.self))
      assertThat(call.arguments, .count(1))
      if call.arguments.count > 0 {
        assertThat(call.arguments[0].label, .isNil)
        assertThat(call.arguments[0].bindingOp, .equals(.copy))
        assertThat(call.arguments[0].value, .isInstance(of: Ident.self))
      }
    }

    pr = parse("f[a := x]", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: SubscriptExpr.self))
    if let call = pr.value as? SubscriptExpr {
      assertThat(call.callee, .isInstance(of: Ident.self))
      assertThat(call.arguments, .count(1))
      if call.arguments.count > 0 {
        assertThat(call.arguments[0].label, .equals("a"))
        assertThat(call.arguments[0].bindingOp, .equals(.copy))
        assertThat(call.arguments[0].value, .isInstance(of: Ident.self))
      }
    }

    pr = parse("f[x, b := y]", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: SubscriptExpr.self))
    if let call = pr.value as? SubscriptExpr {
      assertThat(call.callee, .isInstance(of: Ident.self))
      assertThat(call.arguments, .count(2))
      if call.arguments.count > 0 {
        assertThat(call.arguments[0].label, .isNil)
        assertThat(call.arguments[0].bindingOp, .equals(.copy))
        assertThat(call.arguments[0].value, .isInstance(of: Ident.self))
      }

      if call.arguments.count > 1 {
        assertThat(call.arguments[1].label, .equals("b"))
        assertThat(call.arguments[1].bindingOp, .equals(.copy))
        assertThat(call.arguments[1].value, .isInstance(of: Ident.self))
      }
    }

    let source = "f[ x , b := y , ]".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: SubscriptExpr.self))
  }

  func testParseEnclosed() {
    var pr: Parser.Result<Expr?>

    pr = parse("(a)", with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: EnclosedExpr.self))
    if let enclosed = pr.value as? EnclosedExpr {
      assertThat(enclosed.expression, .isInstance(of: Ident.self))
    }

    let source = "( a )".split(separator: " ").joined(separator: "\n")
    pr = parse(source, with: Parser.parseExpression)
    assertThat(pr.errors, .isEmpty)
    assertThat(pr.value, .isInstance(of: EnclosedExpr.self))
    if let enclosed = pr.value as? EnclosedExpr {
      assertThat(enclosed.expression, .isInstance(of: Ident.self))
    }
  }

}
