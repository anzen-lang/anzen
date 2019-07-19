import AST

extension Parser {

  /// Parses a single statement.
  func parseStatement() -> Result<Node?> {
    switch peek().kind {
    case .hashMark:
      // Currently, only function declarations can be annotated with compiler directives. Therefore
      // we can simply parse a sequence of directives, followed by a function declaration, and add
      // the directives to the latter. In the future, directives might be more difficult to handle
      // as some may affect the parser's state (e.g. conditional compilation).

      // Parse a sequence of directives.
      var directives: [Directive] = []
      var errors: [ParseError] = []
      repeat {
        consumeNewlines()
        guard let parseResult = attempt(parseDirective)
          else { break }

        errors.append(contentsOf: parseResult.errors)
        directives.append(parseResult.value)
      } while true

      // Parse a function declaration.
      consumeNewlines()
      let parseResult = parseStatement()
      errors.append(contentsOf: parseResult.errors)

      guard parseResult.value != nil else { return parseResult }
      guard let declaration = parseResult.value as? FunDecl else {
        return Result(
          value: parseResult.value,
          errors: errors + [
            unexpectedConstruction(expected: "function declaration", got: parseResult.value!),
          ])
      }

      declaration.directives = directives
      return Result(value: declaration, errors: errors)

    case .static, .mutating:
      // If the statement starts with a member attribute, it can describe either a property or a
      // function declaration. Hence we need to parse all attributes before we can desambiguise.
      let startToken = peek()
      var attributes: Set<MemberAttribute> = []

      attrs:while true {
        consumeNewlines()
        switch peek().kind {
        case .static:
          consume()
          attributes.insert(.static)

        case .mutating:
          consume()
          attributes.insert(.mutating)

        case .let, .var, .fun:
          break attrs

        default:
          // As the next token does not indicate a property or a method declaration, we should give
          // up until the end of the line.
          consumeMany(while: { !$0.isStatementDelimiter })
          return Result(
            value: nil,
            errors: [unexpectedToken(expected: "property of function declaration")])
        }
      }

      let parseResult = parseStatement()
      guard let declaration = parseResult.value
        else { return parseResult }
      assert(declaration is PropDecl || declaration is FunDecl)

      declaration.range = SourceRange(from: startToken.range.start, to: declaration.range.end)
      if let propertyDeclaration = declaration as? PropDecl {
        propertyDeclaration.attributes.formUnion(attributes)
      } else if let methodDeclaration = declaration as? FunDecl {
        methodDeclaration.attributes.formUnion(attributes)
      }

      return Result(value: declaration, errors: parseResult.errors)

    case .let, .var:
      let parseResult = parsePropDecl()
      return Result(value: parseResult.value, errors: parseResult.errors)

    case .fun, .new, .del:
      let parseResult = parseFunDecl()
      return Result(value: parseResult.value, errors: parseResult.errors)

    case .struct:
      let parseResult = parseStructDecl()
      return Result(value: parseResult.value, errors: parseResult.errors)

    case .interface:
      let parseResult = parseInterfaceDecl()
      return Result(value: parseResult.value, errors: parseResult.errors)

    case .while:
      let parseResult = parseWhileLoop()
      return Result(value: parseResult.value, errors: parseResult.errors)

    case .return:
      let parseResult = parseReturnStmt()
      return Result(value: parseResult.value, errors: parseResult.errors)

    default:
      // Attempt to parse a binding statement before falling back to an expression.
      if let parseResult = attempt(parseBindingStmt) {
        return Result(value: parseResult.value, errors: parseResult.errors)
      }

      let parseResult = parseExpression()
      return Result(value: parseResult.value, errors: parseResult.errors)
    }
  }

  /// Parses a block of statements, delimited by braces.
  func parseStatementBlock() -> Result<Block?> {
    // The first token should be left brace.
    guard let startToken = consume(.leftBrace) else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "'{'")])
    }

    var errors: [ParseError] = []

    // Skip trailing new lines.
    consumeNewlines()

    // Parse as many statements as possible
    var statements: [Node] = []
    while peek().kind != .rightBrace {
      // Parse a statement.
      let statementParseResult = parseStatement()
      errors.append(contentsOf: statementParseResult.errors)
      if let statement = statementParseResult.value {
        statements.append(statement)
      }

      // If the next token isn't the block delimiter, we MUST parse a statement delimiter.
      if peek().kind != .rightBrace {
        guard peek().isStatementDelimiter else {
          errors.append(parseFailure(.expectedStatementDelimiter))
          consumeMany(while: { !$0.isStatementDelimiter && ($0.kind != .rightBrace) })
          continue
        }

        consumeNewlines()
      }

      // Make sure we didn't reach the end of the stream.
      guard peek().kind != .eof else {
        errors.append(unexpectedToken(expected: "'}'"))
        break
      }
    }

    let endToken = consume()!
    return Result(
      value: Block(
        statements: statements,
        module: module,
        range: SourceRange(from: startToken.range.start, to: endToken.range.end)),
      errors: errors)
  }

  /// Parses a while-loop.
  func parseWhileLoop() -> Result<WhileLoop?> {
    // The first token should be `return`.
    guard let startToken = consume(.while) else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "'while'")])
    }

    var errors: [ParseError] = []

    // Parse the condition.
    let backtrackPosition = streamPosition
    consumeNewlines()
    let conditionParseResult = parseExpression()
    errors.append(contentsOf: conditionParseResult.errors)

    var condition: Expr?
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

    guard let body = thenParseResult.value else {
      return Result(value: nil, errors: errors)
    }

    guard condition != nil else {
      return Result(value: nil, errors: errors)
    }

    return Result(
      value: WhileLoop(
        condition: condition!,
        body: body,
        module: module,
        range: SourceRange(from: startToken.range.start, to: body.range.end)),
      errors: errors)
  }

  /// Parses a return statement.
  func parseReturnStmt() -> Result<ReturnStmt?> {
    // The first token should be `return`.
    guard let startToken = consume(.return) else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "'return'")])
    }

    var errors: [ParseError] = []

    // Attempt to parse a return value.
    if let operatorToken = consume(afterMany: .newline, if: { $0.isBindingOperator }) {
      consumeNewlines()
      let parseResult = parseExpression()
      errors.append(contentsOf: parseResult.errors)

      if let expression = parseResult.value {
        let binding = (operatorToken.asBindingOperator!, expression)
        return Result(
          value: ReturnStmt(
            binding: binding,
            module: module,
            range: SourceRange(from: startToken.range.start, to: expression.range.end)),
          errors: errors)
      }
    } else if let assignOperator = consume(.assign, afterMany: .newline) {
      // Catch invalid uses of the "assign" token in lieu of a binding operator.
      errors.append(ParseError(
        .unexpectedToken(expected: "binding operator", got: assignOperator),
        range: assignOperator.range))

      // Parse the expression in case it contains syntax errors as well.
      let parseResult = parseExpression()
      errors.append(contentsOf: parseResult.errors)
    }

    return Result(value: ReturnStmt(module: module, range: startToken.range), errors: [])
  }

  /// Parses a binding statement.
  func parseBindingStmt() -> Result<BindingStmt?> {
    var errors: [ParseError] = []

    // Parse the left operand.
    let leftParseResult = parseExpression()
    errors.append(contentsOf: leftParseResult.errors)

    guard let lvalue = leftParseResult.value else {
      consumeUpToNextStatementDelimiter()
      return Result(value: nil, errors: errors)
    }

    // Parse the binding operator.
    guard let operatorToken = consume(afterMany: .newline, if: { $0.isBindingOperator }) else {
      consumeUpToNextStatementDelimiter()
      return Result(value: nil, errors: errors + [unexpectedToken(expected: "binding operator")])
    }

    // Parse the right operand.
    consumeNewlines()
    let rightParseResult = parseExpression()
    errors.append(contentsOf: leftParseResult.errors)

    guard let rvalue = rightParseResult.value else {
      consumeUpToNextStatementDelimiter()
      return Result(value: nil, errors: errors)
    }

    return Result(
      value: BindingStmt(
        lvalue: lvalue,
        op: operatorToken.asBindingOperator!,
        rvalue: rvalue,
        module: module,
        range: SourceRange(from: lvalue.range.start, to: rvalue.range.end)),
      errors: errors)
  }

  /// Parses a directive.
  func parseDirective() -> Result<Directive?> {
    // The first token should be `#`.
    guard let startToken = consume(.hashMark) else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "'#'")])
    }

    // Notice that we require the directive's name and arguments to start at the same line.

    // Parse the name of the directive.
    guard let name = consume(.identifier) else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "identifier")])
    }

    // Attempt to parse an argument list.
    var arguments: [String] = []
    var errors: [ParseError] = []
    var end = name.range.end

    if consume(.leftParen) != nil {
      // Commit to parse an argument list.
      let argumentsParseResult = parseList(delimitedBy: TokenKind.rightParen) {
        () -> Result<String?> in
          guard let argument = consume(.identifier) else {
            defer { consume() }
            return Result(value: nil, errors: [unexpectedToken(expected: "identifier")])
          }

          end = argument.range.end
          return Result(value: argument.value, errors: [])
      }

      arguments = argumentsParseResult.value
      if let delimiter = consume(.rightParen) {
        end = delimiter.range.end
      } else {
        errors.append(unexpectedToken(expected: "')'"))
      }
    }

    return Result(
      value: Directive(
        name: name.value!,
        arguments: arguments,
        module: module,
        range: SourceRange(from: name.range.start, to: end)),
      errors: errors)
  }

}
