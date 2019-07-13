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
  func parseExpression() -> Result<Expr?> {
    // Parse the left operand.
    let atomParseResult = parseAtom()
    var errors = atomParseResult.errors

    guard var expression = atomParseResult.value else {
      return Result(value: nil, errors: errors)
    }

    // Attempt to parse the remainder of a binary expression.
    while true {
      // Attempt to consume an infix operator.
      let backtrackPosition = streamPosition
      consumeNewlines()
      guard let infixOperator = peek().asInfixOperator else {
        rewind(to: backtrackPosition)
        break
      }

      // Commit to parsing a binary expression.
      consume()
      consumeNewlines()

      if infixOperator == .as {
        // If the infix operator is a cast operator, then we MUST parse a type signature.
        let signatureParseResult = parseTypeSign()
        errors.append(contentsOf: signatureParseResult.errors)

        guard let castType = signatureParseResult.value else {
          return Result(value: expression, errors: errors)
        }

        expression = CastExpr(
          operand: expression,
          castType: castType,
          module: module,
          range: SourceRange(from: expression.range.start, to: castType.range.end))
        continue
      }

      // Other infix operators work on expressions, so we MUST parse a right operand.
      let rightParseResult = parseAtom()
      errors.append(contentsOf: rightParseResult.errors)

      guard let rightOperand = rightParseResult.value else {
        return Result(value: nil, errors: errors)
      }

      // If the left operand is a binary expression, we should check the precedence of its operator
      // and potentially reorder the operands.
      if let binExpr = expression as? BinExpr, binExpr.op.precedence < infixOperator.precedence {
        let left = binExpr.left
        let right = BinExpr(
          left: binExpr.right,
          op: infixOperator,
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
          op: infixOperator,
          right: rightOperand,
          module: module,
          range: SourceRange(from: expression.range.start, to: rightOperand.range.end))
      }
    }

    return Result(value: expression, errors: errors)
  }

  /// Parses an atom.
  func parseAtom() -> Result<Expr?> {
    let token = peek()
    let startLocation = token.range.start

    var expression: Expr
    var errors: [ParseError] = []

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
      let parseResult = parseUnExpr()
      errors = parseResult.errors
      guard let node = parseResult.value else {
        return Result(value: nil, errors: errors)
      }
      expression = node

    case .identifier:
      let parseResult = parseIdentifier()
      errors = parseResult.errors
      guard let node = parseResult.value else {
        return Result(value: nil, errors: errors)
      }
      expression = node

    case .if:
      let parseResult = parseIfExpr()
      errors = parseResult.errors
      guard let node = parseResult.value else {
        return Result(value: nil, errors: errors)
      }
      expression = node

    case .fun:
      let parseResult = parseLambdaExpr()
      errors = parseResult.errors
      guard let node = parseResult.value else {
        return Result(value: nil, errors: errors)
      }
      expression = node

    case .leftBracket:
      let parseResult = parseArrayLiteral()
      errors = parseResult.errors
      guard let node = parseResult.value else {
        return Result(value: nil, errors: errors)
      }
      expression = node

    case .leftBrace:
      let parseResult = parseMapOrSetLiteral()
      errors = parseResult.errors
      guard let node = parseResult.value else {
        return Result(value: nil, errors: errors)
      }
      expression = node

    case .dot:
      consume()
      let identifierParseResult = parseIdentifier(allowOperators: true)
      errors.append(contentsOf: identifierParseResult.errors)
      guard let identifier = identifierParseResult.value else {
        return Result(value: nil, errors: errors)
      }

      expression = SelectExpr(
        ownee: identifier,
        module: module,
        range: SourceRange(from: token.range.start, to: identifier.range.end))

    case .leftParen:
      consume()
      consumeNewlines()
      let enclosedParseResult = parseExpression()
      errors.append(contentsOf: enclosedParseResult.errors)
      guard let enclosed = enclosedParseResult.value else {
        return Result(value: nil, errors: errors)
      }

      let delimiter = consume(.rightParen, afterMany: .newline)
      if delimiter == nil {
        errors.append(unexpectedToken(expected: "')'"))
      }

      expression = EnclosedExpr(
        enclosing: enclosed,
        module: module,
        range: SourceRange(from: startLocation, to: delimiter!.range.end))

    default:
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "expression")])
    }

    // NOTE: Although it wouldn't make the grammar ambiguous otherwise, notice that we require
    // trailers to start at the same line. The rationale is that it doing otherwise could easily
    // make some portions of code *look* ambiguous.
    trailer:while true {
      if consume(.leftParen) != nil {
        let argumentsParseResult = parseList(
          delimitedBy: .rightParen,
          parsingElementWith: parseCallArg)
        errors.append(contentsOf: argumentsParseResult.errors)

        // Consume the delimiter of the list.
        let endToken = consume(.rightParen)
        if endToken == nil {
          errors.append(unexpectedToken(expected: "')'"))
        }
        let end = endToken?.range.end ?? expression.range.end

        expression = CallExpr(
          callee: expression,
          arguments: argumentsParseResult.value,
          module: module,
          range: SourceRange(from: expression.range.start, to: end))

        continue trailer
      } else if consume(.leftBracket) != nil {
        let argumentsParseResult = parseList(
          delimitedBy: .rightBracket,
          parsingElementWith: parseCallArg)
        errors.append(contentsOf: argumentsParseResult.errors)

        // Consume the delimiter of the list.
        let endToken = consume(.rightBracket)
        if endToken == nil {
          errors.append(unexpectedToken(expected: "']'"))
        }
        let end = endToken?.range.end ?? expression.range.end

        expression = SubscriptExpr(
          callee: expression,
          arguments: argumentsParseResult.value,
          module: module,
          range: SourceRange(from: expression.range.start, to: end))

        continue trailer
      }

      // Consuming new lines here allow us to parse select expressions split over several lines.
      // However, if the next consumable token isn't a dot, we need to backtrack, so as to avoid
      // consuming possibly significant new lines.
      let backtrackPosition = streamPosition
      if consume(.dot, afterMany: .newline) != nil {
        let identifierParseResult = parseIdentifier(allowOperators: true)
        errors.append(contentsOf: identifierParseResult.errors)
        guard let identifier = identifierParseResult.value else {
          return Result(value: nil, errors: errors)
        }

        expression = SelectExpr(
          owner: expression,
          ownee: identifier,
          module: module,
          range: SourceRange(from: expression.range.start, to: identifier.range.end))

        continue trailer
      }

      // No more trailer to parse.
      rewind(to: backtrackPosition)
      break
    }

    return Result(value: expression, errors: errors)
  }

  /// Parses an unary expression.
  func parseUnExpr() -> Result<UnExpr?> {
    // The first token must be an unary operator.
    guard let operatorToken = consume(if: { $0.isPrefixOperator }) else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "unary operator")])
    }

    // Parse the expression.
    let operandParseResult = parseExpression()
    guard let operand = operandParseResult.value else {
      return Result(value: nil, errors: operandParseResult.errors)
    }

    return Result(
      value: UnExpr(
        op: operatorToken.asPrefixOperator!,
        operand: operand,
        module: module,
        range: SourceRange(from: operatorToken.range.start, to: operand.range.end)),
      errors: operandParseResult.errors)
  }

  /// Parses an identifier.
  func parseIdentifier(allowOperators: Bool = false) -> Result<Ident?> {
    let identifier: Ident
    var errors: [ParseError] = []

    // The first token is either an identifier or an operator (provided `allowsOperator` is set).
    if let name = consume(.identifier) {
      identifier = Ident(name: name.value!, module: module, range: name.range)
    } else if allowOperators, let op = consume(if: { $0.isPrefixOperator || $0.isInfixOperator }) {
      identifier = Ident(name: op.kind.rawValue, module: module, range: op.range)
    } else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "identifier")])
    }

    // Attempt to parse a specialization list.
    let backtrackPosition = streamPosition
    consumeNewlines()
    if peek().kind == .lt, let specializationsParseResult = attempt(parseSpecializationList) {
      errors.append(contentsOf: specializationsParseResult.errors)
      for (token, value) in specializationsParseResult.value {
        // Make sure there are no duplicate keys.
        guard identifier.specializations[token.value!] == nil else {
          errors.append(ParseError(.duplicateKey(key: token.value!), range: token.range))
          continue
        }
        identifier.specializations[token.value!] = value
      }
    } else {
      rewind(to: backtrackPosition)
    }

    return Result(value: identifier, errors: errors)
  }

  /// Parses a conditional expression.
  func parseIfExpr() -> Result<IfExpr?> {
    // The first token should be `if`.
    guard let startToken = consume(.if) else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "'if'")])
    }

    var errors: [ParseError] = []

    // Parse the condition.
    let backtrackPosition = streamPosition
    consumeNewlines()
    let conditionParseResult = parseExpression()
    errors.append(contentsOf: conditionParseResult.errors)

    var condition: Expr? = nil
    if let expression = conditionParseResult.value {
      condition = expression
    } else {
      // Although we cannot create a conditional node without successfully parsing its condition,
      // we'll attempt to parse the remainder of the expression anyway.
      rewind(to: backtrackPosition)
      consumeMany(while: { !$0.isStatementDelimiter && ($0.kind != .leftBrace) })
    }

    // Parse the first block of statements (i.e. the "then" clause).
    consumeNewlines()
    let thenParseResult = parseStatementBlock()
    errors.append(contentsOf: thenParseResult.errors)

    guard let thenBlock = thenParseResult.value else {
      return Result(value: nil, errors: errors)
    }

    // Attempt to parse an optional else block.
    var elseBlock: Node? = nil
    if consume(.else, afterMany: .newline) != nil {
      // Commit to parse the else block.
      consumeNewlines()

      if peek().kind == .if {
        let conditionalElseParseResult = parseIfExpr()
        errors.append(contentsOf: conditionParseResult.errors)
        elseBlock = conditionalElseParseResult.value
      } else {
        let elseParseResult = parseStatementBlock()
        errors.append(contentsOf: conditionParseResult.errors)
        elseBlock = elseParseResult.value
      }
    }

    guard condition != nil else {
      return Result(value: nil, errors: errors)
    }

    let end = elseBlock?.range.end ?? thenBlock.range.end
    return Result(
      value: IfExpr(
        condition: condition!,
        thenBlock: thenBlock,
        elseBlock: elseBlock,
        module: module,
        range: SourceRange(from: startToken.range.start, to: end)),
      errors: errors)
  }

  /// Parses a lambda expression.
  func parseLambdaExpr() -> Result<LambdaExpr?> {
    // The first token should be `fun`.
    guard let startToken = consume(.fun) else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "'fun'")])
    }

    var errors: [ParseError] = []

    // Attempt to parse a parameter list.
    var parameters: [ParamDecl] = []
    if consume(.leftParen, afterMany: .newline) != nil {
      // Commit to parse a parameter list.
      let parametersParseResult = parseList(
        delimitedBy: .rightParen,
        parsingElementWith: parseParamDecl)
      errors.append(contentsOf: parametersParseResult.errors)

      // Make sure there are no duplicate parameters.
      var existing: Set<String> = []
      for parameter in parametersParseResult.value {
        guard !existing.contains(parameter.name) else {
          errors.append(
            ParseError(.duplicateParameter(name: parameter.name), range: parameter.range))
          continue
        }
        existing.insert(parameter.name)
      }

      parameters = parametersParseResult.value
      if consume(.rightParen) == nil {
        errors.append(unexpectedToken(expected: "')'"))
      }
    }

    // Attempt to parse a codomain.
    var codomain: Node? = nil
    if consume(.arrow, afterMany: .newline) != nil {
      consumeNewlines()
      let backtrackPosition = streamPosition
      let codomainParseResult = parseQualSign()
      errors.append(contentsOf: codomainParseResult.errors)

      if let signature = codomainParseResult.value {
        codomain = signature
      } else {
        rewind(to: backtrackPosition)
        consumeMany(while: { !$0.isStatementDelimiter && ($0.kind != .leftBrace) })
      }
    }

    // Parse the body of the lambda.
    consumeNewlines()
    let blockParseResult = parseStatementBlock()
    errors.append(contentsOf: blockParseResult.errors)

    guard let body = blockParseResult.value else {
      return Result(value: nil, errors: errors)
    }

    return Result(
      value: LambdaExpr(
        parameters: parameters,
        codomain: codomain,
        body: body,
        module: module,
        range: SourceRange(from: startToken.range.start, to: body.range.end)),
      errors: errors)
  }

  /// Parses a call argument.
  func parseCallArg() -> Result<CallArg?> {
    var errors: [ParseError] = []

    // Attempt to parse an explicit parameter assignment (i.e. `label operator expression`).
    let backtrackPosition = streamPosition
    if let token = consume(.identifier) {
      // Attempt to parse a binding operator.
      if let operatorToken = consume(afterMany: .newline, if: { $0.isBindingOperator }) {
        // Commit to parsing an explicit parameter assignment (i.e. `label operator expression`).
        consumeNewlines()
        let parseResult = parseExpression()
        errors.append(contentsOf: parseResult.errors)

        guard let expression = parseResult.value else {
          return Result(value: nil, errors: errors)
        }

        return Result(
          value: CallArg(
            label: token.value,
            bindingOp: operatorToken.asBindingOperator!,
            value: expression,
            module: module,
            range: SourceRange(from: token.range.start, to: expression.range.end)),
          errors: errors)
      } else {
        // If we couldn't parse the remainder of an explicit parameter assignment, we rewind an
        // attempt to parse a simple expression instead.
        rewind(to: backtrackPosition)
      }
    }

    // Parse the argument's value.
    let argumentParseResult = parseExpression()
    errors.append(contentsOf: argumentParseResult.errors)

    guard let value = argumentParseResult.value else {
      return Result(value: nil, errors: errors)
    }

    return Result(
      value: CallArg(
        label: nil, bindingOp: .copy,
        value: value,
        module: module,
        range: value.range),
      errors: errors)
  }

  /// Parses an array literal.
  func parseArrayLiteral() -> Result<ArrayLiteral?> {
    // The first token must be left bracket.
    guard let startToken = consume(.leftBracket) else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "'['")])
    }

    var errors: [ParseError] = []

    // Parse the array elements.
    let elementsParseResult = parseList(
      delimitedBy: .rightBracket,
      parsingElementWith: parseExpression)
    errors.append(contentsOf: elementsParseResult.errors)

    // Parse the expression's delimiter.
    guard let endToken = consume(.rightBracket) else {
      defer { consumeUpToNextStatementDelimiter() }
      return Result(value: nil, errors: errors + [unexpectedToken(expected: "']'")])
    }

    return Result(
      value: ArrayLiteral(
        elements: elementsParseResult.value,
        module: module,
        range: SourceRange(from: startToken.range.start, to: endToken.range.end)),
      errors: errors)
  }

  /// Parses a map or set literal.
  ///
  /// Map and set liteals are similar in that they are a list of elements enclosed in braces, which
  /// complicates error reporting. We choose to commit on whether we're parsing a map or a set
  /// literal based on the successful parsing of the first element.
  ///
  /// Note that a colon is required to distinguish between empty set literals and map literals, so
  /// that `{}` is parsed as an empty set literal and `{:}` is parser as the empty map literal.
  func parseMapOrSetLiteral() -> Result<Expr?> {
    // The first token must be brace bracket.
    guard let startToken = consume(.leftBrace) else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "'{'")])
    }

    // If the next consumable token is the right delimiter, we've got an empty set literal.
    if let endToken = consume(.rightBrace, afterMany: .newline) {
      return Result(
        value: SetLiteral(
          elements: [],
          module: module,
          range: SourceRange(from: startToken.range.start, to: endToken.range.start)),
        errors: [])
    }

    // If the next consumable token is a colon, we've probably got an empty map literal.
    if consume(.colon, afterMany: .newline) != nil {
      // Commit to parsing the empty map literal.
      guard let endToken = consume(.rightBrace, afterMany: .newline) else {
        defer { consumeUpToNextStatementDelimiter() }
        return Result(value: nil, errors: [unexpectedToken(expected: "'}'")])
      }

      return Result(
        value: MapLiteral(
          elements: [:],
          module: module,
          range: SourceRange(from: startToken.range.start, to: endToken.range.start)),
        errors: [])
    }

    var errors: [ParseError] = []

    // Attempt to parse a map element.
    consumeNewlines()
    let backtrackPosition = streamPosition
    let firstMapElementParseResult = parseMapElement()
    rewind(to: backtrackPosition)

    if let firstMapElement = firstMapElementParseResult.value {
      // Commit to parsing a map literal.
      let mapElementsParseResult = parseMapElements()
      errors.append(contentsOf: mapElementsParseResult.errors)

      // Parse the expression's delimiter.
      guard let endToken = consume(.rightBrace) else {
        defer { consumeUpToNextStatementDelimiter() }
        return Result(value: nil, errors: errors + [unexpectedToken(expected: "'}'")])
      }

      return Result(
        value: MapLiteral(
          elements: mapElementsParseResult.value,
          module: module,
          range: SourceRange(from: startToken.range.start, to: endToken.range.end)),
        errors: errors)
    } else {
      // Commit to parsing a set literal.
      let setElementsParseResult = parseList(
        delimitedBy: .rightBrace,
        parsingElementWith: parseExpression)
      errors.append(contentsOf: setElementsParseResult.errors)

      // Parse the expression's delimiter.
      guard let endToken = consume(.rightBrace) else {
        defer { consumeUpToNextStatementDelimiter() }
        return Result(value: nil, errors: errors + [unexpectedToken(expected: "'}'")])
      }

      return Result(
        value: SetLiteral(
          elements: setElementsParseResult.value,
          module: module,
          range: SourceRange(from: startToken.range.start, to: endToken.range.end)),
        errors: errors)
    }
  }

  /// Parses a sequence of key/value pairs as the elements of a map literal.
  func parseMapElements() -> Result<[String: Expr]> {
    var errors: [ParseError] = []

    // Parse the map elements.
    let elementsParseResult = parseList(
      delimitedBy: .rightBrace,
      parsingElementWith: parseMapElement)
    errors.append(contentsOf: elementsParseResult.errors)

    var elements: [String: Expr] = [:]
    for (token, value) in elementsParseResult.value {
      // Make sure there are no duplicate keys.
      guard elements[token.value!] == nil else {
        errors.append(ParseError(.duplicateKey(key: token.value!), range: token.range))
        continue
      }
      elements[token.value!] = value
    }

    return Result(value: elements, errors: errors)
  }

  /// Parses a map literal element.
  func parseMapElement() -> Result<(Token, Expr)?> {
    // Parse the key of the element.
    guard let key = consume(.identifier) else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "identifier")])
    }

    var errors: [ParseError] = []

    // Parse the value of the element.
    guard consume(.colon, afterMany: .newline) != nil else {
      defer { consumeUpToNextStatementDelimiter() }
      return Result(value: nil, errors: [unexpectedToken(expected: "':'")])
    }

    consumeNewlines()
    let valueParseResult = parseExpression()
    errors.append(contentsOf: valueParseResult.errors)
    guard let value = valueParseResult.value else {
      return Result(value: nil, errors: errors)
    }

    return Result(value: (key, value), errors: errors)
  }

}
