import AST
import Utils

extension Parser {

  /// Parses an expression.
  ///
  /// Use this parse method as the entry point to parse any Anzen expression.
  ///
  /// Because this parser is implemented as a recursive descent parser, a particular attention must
  /// be made as to how expressions can be parsed witout triggering infinite recursions, due to the
  /// left-recursion of the related production rules.
  func parseExpression() throws -> Expr {
    // Parse the left operand.
    var expression = try parseAtom()

    // Attempt to parse the remainder of a binary expression.
    while true {
      // Attempt to consume an infix operator.
      let backtrackPosition = streamPosition
      consumeNewlines()
      guard let op = peek().asInfixOperator else {
        rewind(to: backtrackPosition)
        break
      }
      consume()

      if op == .as {
        // If the infix operator is a cast operator, then we MUST parse a type signature.
        let castType = try parseTypeSign()
        expression = CastExpr(
          operand: expression,
          castType: castType,
          module: module,
          range: SourceRange(from: expression.range.start, to: castType.range.end))
        continue
      }

      // Other infix operators work on expressions, so we MUST parse a right operand as such.
      let rightOperand = try parseAtom()

      // If the left operand is a binary expression, we should check the precedence of its operator
      // and potentially reorder the operands.
      if let binExpr = expression as? BinExpr, binExpr.op.precedence < op.precedence {
        let left = binExpr.left
        let right = BinExpr(
          left: binExpr.right,
          op: op,
          right: rightOperand,
          module: module,
          range: SourceRange(from: binExpr.right.range.start, to: rightOperand.range.end))
        expression = BinExpr(
          left: left,
          op: binExpr.op,
          right: right,
          module: module,
          range: SourceRange(from: left.range.start, to: right.range.end))
      } else {
        expression = BinExpr(
          left: expression,
          op: op,
          right: rightOperand,
          module: module,
          range: SourceRange(from: expression.range.start, to: rightOperand.range.end))
      }
    }

    return expression
  }

  /// Parses an atom.
  func parseAtom() throws -> Expr {
    let token = peek()
    let startLocation = token.range.start

    var expression: Expr
    switch token.kind {
    case .integer:
      consume()
      expression = Literal(value: Int(token.value!)!, module: module, range: token.range)
    case .float:
      consume()
      expression = Literal(value: Double(token.value!)!, module: module, range: token.range)
    case .string:
      consume()
      expression = Literal(value: token.value!, module: module, range: token.range)
    case .bool:
      consume()
      expression = Literal(value: token.value == "true", module: module, range: token.range)

    case _ where token.isPrefixOperator:
      expression = try parseUnExpr()
    case .identifier:
      expression = try parseIdentifier()
    case .if:
      expression = try parseIfExpr()
    case .fun:
      expression = try parseLambdaExpr()
    case .leftBracket:
      expression = try parseArrayLiteral()
    case .leftBrace:
      expression = try attempt(parseMapLiteral) ?? parseSetLiteral()

    case .dot:
      consume()
      guard peek().kind == .identifier || peek().isPrefixOperator || peek().isInfixOperator
        else { throw parseFailure(.expectedMember) }
      let ident = try parseIdentifier(allowOperators: true)

      expression = SelectExpr(
        ownee: ident,
        module: module,
        range: SourceRange(from: token.range.start, to: ident.range.end))

    case .leftParen:
      consume()
      consumeNewlines()
      let enclosed = try parseExpression()
      guard let delimiter = consume(.rightParen, afterMany: .newline)
        else { throw unexpectedToken(expected: ")") }
      expression = EnclosedExpr(
        enclosing: enclosed,
        module: module,
        range: SourceRange(from: startLocation, to: delimiter.range.end))

    default:
      throw unexpectedToken(expected: "expression")
    }

    // NOTE: Although it wouldn't make the grammar ambiguous otherwise, notice that we require
    // trailers to start at the same line. The rationale is that it doing otherwise could easily
    // make some portions of code *look* ambiguous.
    trailer:while true {
      if consume(.leftParen) != nil {
        let args = try parseList(delimitedBy: .rightParen, parsingElementWith: parseCallArg)

        // Consume the delimiter of the list.
        guard let endToken = consume(.rightParen)
          else { throw unexpectedToken(expected: ")") }

        expression = CallExpr(
          callee: expression,
          arguments: args,
          module: module,
          range: SourceRange(from: expression.range.start, to: endToken.range.end))
        continue trailer
      } else if consume(.leftBracket) != nil {
        let args = try parseList(delimitedBy: .rightBracket, parsingElementWith: parseCallArg)

        // Consume the delimiter of the list.
        guard let endToken = consume(.rightBracket)
          else { throw unexpectedToken(expected: ")") }

        expression = SubscriptExpr(
          callee: expression,
          arguments: args,
          module: module,
          range: SourceRange(from: expression.range.start, to: endToken.range.end))
        continue trailer
      }

      // Consuming new lines here allow us to parse select expressions split over several lines.
      // However, if the next consumable token isn't a dot, we need to backtrack, so as to avoid
      // consuming possibly significant new lines.
      let backtrackPosition = streamPosition
      if consume(.dot, afterMany: .newline) != nil {
        guard peek().kind == .identifier || peek().isPrefixOperator || peek().isInfixOperator
          else { throw parseFailure(.expectedMember) }
        let ident = try parseIdentifier(allowOperators: true)

        expression = SelectExpr(
          owner: expression,
          ownee: ident,
          module: module,
          range: SourceRange(from: expression.range.start, to: ident.range.end))
        continue trailer
      }

      // No more trailer to parse.
      rewind(to: backtrackPosition)
      break
    }

    return expression
  }

  /// Parses an unary expression.
  func parseUnExpr() throws -> UnExpr {
    guard let op = consume(), op.isPrefixOperator
      else { throw unexpectedToken(expected: "unary operator") }

    let operand = try parseExpression()
    return UnExpr(
      op: op.asPrefixOperator!,
      operand: operand,
      module: module,
      range: SourceRange(from: op.range.start, to: operand.range.end))
  }

  /// Parses an identifier.
  func parseIdentifier(allowOperators: Bool = false) throws -> Ident {
    let ident: Ident
    if let name = consume(.identifier) {
      ident = Ident(name: name.value!, module: module, range: name.range)
    } else if allowOperators, let op = consume(if: { $0.isPrefixOperator || $0.isInfixOperator }) {
      ident = Ident(name: op.kind.rawValue, module: module, range: op.range)
    } else {
      throw unexpectedToken(expected: "identifier")
    }

    // Attempt to parse the specialization list.
    let backtrackPosition = streamPosition
    consumeNewlines()
    if peek().kind == .lt, let keysAndValues = attempt(parseSpecializationList) {
      // Make sure there's no duplicate key.
      let duplicates = keysAndValues.duplicates { $0.0.value! }
      guard duplicates.isEmpty else {
        let key = duplicates.first!.0
        throw ParseError(.duplicateKey(key: key.value!), range: key.range)
      }
      ident.specializations = Dictionary(
        uniqueKeysWithValues: keysAndValues.map({ ($0.0.value!, $0.1) }))
    } else {
      rewind(to: backtrackPosition)
    }

    return ident
  }

  /// Parses a conditional expression.
  func parseIfExpr() throws -> IfExpr {
    guard let startToken = consume(.if)
      else { throw unexpectedToken(expected: "if") }

    // Parse the condition.
    consumeNewlines()
    let condition = try parseExpression()

    // Parse a block of statements.
    consumeNewlines()
    let thenBlock = try parseStatementBlock()

    // Parse the optional else block.
    let elseBlock = attempt { () -> Node in
      guard consume(.else, afterMany: .newline) != nil
        else { throw unexpectedToken(expected: "else") }

      consumeNewlines()
      if let block = attempt(parseIfExpr) {
        return block
      } else {
        return try parseStatementBlock()
      }
    }

    let end = elseBlock?.range.end ?? thenBlock.range.end
    return IfExpr(
      condition: condition,
      thenBlock: thenBlock,
      elseBlock: elseBlock,
      module: module,
      range: SourceRange(from: startToken.range.start, to: end))
  }

  /// Parses a lambda expression.
  func parseLambdaExpr() throws -> LambdaExpr {
    guard let startToken = consume(.fun)
      else { throw unexpectedToken(expected: "fun") }

    // Parse the optional parameter list.
    var parameters: [ParamDecl] = []
    if consume(.leftParen, afterMany: .newline) != nil {
      parameters = try parseList(delimitedBy: .rightParen, parsingElementWith: parseParamDecl)
      guard consume(.rightParen) != nil
        else { throw unexpectedToken(expected: ")") }
    }

    // Parse the optional codomain.
    var codomain: Node? = nil
    if consume(.arrow, afterMany: .newline) != nil {
      consumeNewlines()
      codomain = try parseQualSign()
    }

    // Parse the body of the lambda.
    consumeNewlines()
    let block = try parseStatementBlock()

    return LambdaExpr(
      parameters: parameters,
      codomain: codomain,
      body: block,
      module: module,
      range: SourceRange(from: startToken.range.start, to: block.range.end))
  }

  /// Parses a call argument.
  func parseCallArg() throws -> CallArg {
    // Parse the optional label and binding operator of the argument.
    var label: Token? = nil
    var bindingOperator: BindingOperator? = nil

    let backtrackPosition = streamPosition
    if let token = consume(.identifier) {
      consumeNewlines()
      if let op = peek().asBindingOperator {
        consume()
        label = token
        bindingOperator = op
        consumeNewlines()
      } else {
        rewind(to: backtrackPosition)
      }
    }

    // Read the argument's value.
    let value = try parseExpression()
    let start = label?.range.start ?? value.range.start
    let arg = CallArg(
      label: label?.value,
      bindingOp: bindingOperator ?? .copy,
      value: value,
      module: module,
      range: SourceRange(from: start, to: value.range.end))
    return arg
  }

  /// Parses an array literal.
  func parseArrayLiteral() throws -> ArrayLiteral {
    guard let startToken = consume(.leftBracket)
      else { throw unexpectedToken(expected: "[") }
    let elements = try parseList(delimitedBy: .rightBracket, parsingElementWith: parseExpression)
    guard let endToken = consume(.rightBracket)
      else { throw unexpectedToken(expected: "]") }

    return ArrayLiteral(
      elements: elements,
      module: module,
      range: SourceRange(from: startToken.range.start, to: endToken.range.end))
  }

  /// Parses a set literal.
  func parseSetLiteral() throws -> SetLiteral {
    guard let startToken = consume(.leftBrace)
      else { throw unexpectedToken(expected: "{") }
    let elements = try parseList(delimitedBy: .rightBrace, parsingElementWith: parseExpression)
    guard let endToken = consume(.rightBrace)
      else { throw unexpectedToken(expected: "}") }

    return SetLiteral(
      elements: elements,
      module: module,
      range: SourceRange(from: startToken.range.start, to: endToken.range.end))
  }

  /// Parses a map literal.
  func parseMapLiteral() throws -> MapLiteral {
    guard let startToken = consume(.leftBrace)
      else { throw unexpectedToken(expected: "{") }
    let keysAndValues = try parseList(delimitedBy: .rightBrace, parsingElementWith: parseMapElement)

    // Make sure there's no duplicate key.
    let duplicates = keysAndValues.duplicates { $0.0.value! }
    guard duplicates.isEmpty else {
      let key = duplicates.first!.0
      throw ParseError(.duplicateKey(key: key.value!), range: key.range)
    }

    // Consume the delimiter of the list.
    guard let endToken = consume(.rightBrace)
      else { throw unexpectedToken(expected: "}") }

    return MapLiteral(
      elements: Dictionary.init(
        uniqueKeysWithValues: keysAndValues.map({ ($0.0.value!, $0.1) })),
      module: module,
      range: SourceRange(from: startToken.range.start, to: endToken.range.end))
  }

  /// Parses a map literal element.
  func parseMapElement() throws -> (Token, Expr) {
    // Parse the key of the element.
    guard let key = consume(.identifier)
      else { throw unexpectedToken(expected: "identifier") }

    // Parse the `:` symbol.
    guard consume(.colon, afterMany: .newline) != nil
      else { throw unexpectedToken(expected: ":") }

    // Parse the value it should maps to.
    consumeNewlines()
    let value = try parseExpression()
    return (key, value)
  }

}
