import AST

extension Parser {

  /// Parses a top-level statement.
  func parseStmt(issues: inout [Issue]) -> ASTNode? {
    switch peek().kind {
    case .if:
      return parseIfStmt(issues: &issues)

    case .while:
      return parseWhileStmt(issues: &issues)

    case .return:
      return parseReturnStmt(issues: &issues)

    default:
      // Parse an expression.
      if let lhs = parseExpr(issues: &issues) {
        // Attempt to parse a binding.
        if consume(if: { $0.isBindingOperator || $0.kind == .assign }, afterMany: .newline) != nil {
          rewind()
          if let binding = parseBinding(issues: &issues) {
            return BindingStmt(
              op: binding.op,
              lvalue: lhs,
              rvalue: binding.value,
              module: module,
              range: lhs.range.lowerBound ..< binding.value.range.upperBound)
          } else {
            assertionFailure()
          }
        } else {
          // If parsing a binding failed, return the parsed expression as a statement.
          return lhs
        }
      }

      // Fail to parse any statement.
      return nil
    }
  }

  /// Parses a brace statement.
  ///
  /// This parser recognizes a sequence of statements (in the broad sense), separated by statement
  /// delimiters (i.e. a newline or `;`) and enclosed in braces. In case of failure to parse a
  /// particular statement, the method tries to recover at the next delimiter.
  func parseBraceStmt(issues: inout [Issue]) -> BraceStmt? {
    // The first token should be a left brace.
    guard let head = consume(.leftBrace) else {
      issues.append(unexpectedToken(expected: "'{'"))
      return nil
    }

    var nodes: [ASTNode] = []

    // Parse as many nodes as possible.
    while peek().kind != .rightBrace {
      // Skip leading new lines in front of the next statement to avoid triggering an error if the
      // end of the sequence has been reached.
      consumeMany(while: { $0.isStatementDelimiter })

      // Stop parsing elements if we reach the block delimiter.
      guard (peek().kind != .rightBrace) && (peek().kind != .eof)
        else { break }

      // Parse the next node.
      if let node = parseTopLevelNode(issues: &issues) {
        nodes.append(node)
      } else {
        recoverAtNextStatementDelimiter()
      }

      if peek().kind != .rightBrace {
        // If the next token isn't a closing brace nor the end of file, we **must** parse a
        // statement delimiter. Otherwise, we assume one is missing and attempt to parse the next
        // statement after raising an issue.
        guard peek().isStatementDelimiter || (peek().kind == .eof) else {
          issues.append(parseFailure(Issue.expectedStmtDelimiter(), range: peek().range))
          continue
        }
      }
    }

    let tail = consume(.rightBrace) ?? peek()
    assert(tail.kind == .rightBrace || tail.kind == .eof)
    if tail.kind == .eof {
      issues.append(unexpectedToken(expected: "'}'"))
    }

    return BraceStmt(
      stmts: nodes,
      module: module,
      range: head.range.lowerBound ..< tail.range.upperBound)
  }

  /// Parses a conditional expression.
  func parseIfStmt(issues: inout [Issue]) -> IfStmt? {
    // The first token should be `if`.
    guard let head = consume(.if) else {
      issues.append(unexpectedToken(expected: "'if'"))
      return nil
    }

    // Parse the statement's condition.
    consumeNewlines()
    var condition = parseExpr(issues: &issues)
    if condition == nil {
      // Although we couldn't parse the statement's condition, we should attempt to parse its body
      // anyway, and so we need to skip the tokens inbetween. Failure to produce any expression
      // likely indicates that the parser encountered an unexpected token, so we'll skip all input
      // until we find an opening brace, an explicit statement delimiter or the end of file.
      let savePoint = streamPosition
      consumeMany(while: {
        ($0.kind != .leftBrace) && ($0.kind != .semicolon) && ($0.kind != .eof)
      })

      guard peek().kind == .leftBrace else {
        // Give up on the current statement if we couldn't find opening braces.
        rewind(to: savePoint)
        return nil
      }

      // Create an invalid expression placeholder for the condition.
      condition = InvalidExpr(module: module, range: head.range)
    }

    // Parse the statement's "then" body.
    consumeNewlines()
    let thenStmt: Stmt = parseBraceStmt(issues: &issues)
      ?? InvalidStmt(module: module, range: head.range)

    var elseStmt: Stmt?
    if consume(.else, afterMany: .newline) != nil {
      // Commit to parse the statement's "else" node. This should be either an `if` statement, or
      // a brace statement.
      consumeNewlines()
      switch peek().kind {
      case .if:
        elseStmt = parseIfStmt(issues: &issues)
      case .leftBrace:
        elseStmt = parseBraceStmt(issues: &issues)
      default:
        issues.append(unexpectedToken(expected: "'{'"))
      }
    }

    return IfStmt(
      condition: condition!,
      thenStmt: thenStmt,
      elseStmt: elseStmt,
      module: module,
      range: head.range.lowerBound ..< (elseStmt ?? thenStmt).range.upperBound)
  }

  /// Parses a while-loop.
  func parseWhileStmt(issues: inout [Issue]) -> WhileStmt? {
    // The first token should be `while`.
    guard let head = consume(.while) else {
      issues.append(unexpectedToken(expected: "'while'"))
      return nil
    }

    // Parse the loop's condition.
    consumeNewlines()
    var condition = parseExpr(issues: &issues)
    if condition == nil {
      // Although we couldn't parse the loop's condition, we should attempt to parse its body
      // anyway, and so we need to skip the tokens inbetween. Failure to produce any expression
      // likely indicates that the parser encountered an unexpected token, so we'll skip all input
      // until we find an opening brace, an explicit statement delimiter or the end of file.
      let savePoint = streamPosition
      consumeMany(while: {
        ($0.kind != .leftBrace) && ($0.kind != .semicolon) && ($0.kind != .eof)
      })

      guard peek().kind == .leftBrace else {
        // Give up on the current statement if we couldn't find opening braces.
        rewind(to: savePoint)
        return nil
      }

      // Create an invalid expression placeholder for the condition.
      condition = InvalidExpr(module: module, range: head.range)
    }

    // Parse the loop's body.
    consumeNewlines()
    let body: Stmt = parseBraceStmt(issues: &issues)
      ?? InvalidStmt(module: module, range: head.range)

    return WhileStmt(
      condition: condition!,
      body: body,
      module: module,
      range: head.range.lowerBound ..< body.range.upperBound)
  }

  /// Parses a return statement.
  func parseReturnStmt(issues: inout [Issue]) -> ReturnStmt? {
    // The first token should be `return`.
    guard let head = consume(.return) else {
      issues.append(unexpectedToken(expected: "'return'"))
      return nil
    }

    // Attempt to parse a binding.
    if consume(if: { $0.isBindingOperator || $0.kind == .assign }, afterMany: .newline) != nil {
      rewind()
      if let binding = parseBinding(issues: &issues) {
        return ReturnStmt(
          binding: binding,
          module: module,
          range: head.range.lowerBound ..< binding.value.range.upperBound)
      } else {
        assertionFailure()
      }
    }

    return ReturnStmt(module: module, range: head.range)
  }

  /// Parses the right side of a binding (i.e. a binding operator with an r-value).
  func parseBinding(issues: inout [Issue]) -> (op: IdentExpr, value: Expr)? {
    let opIdent: IdentExpr

    if let opToken = consume(if: { $0.isBindingOperator }) {
      opIdent = IdentExpr(name: opToken.value!, module: module, range: opToken.range)
    } else if let opToken = consume(.assign) {
      // Catch invalid uses of the "assign" token in lieu of a binding operator.
      opIdent = IdentExpr(name: ":=", module: module, range: opToken.range)
      issues.append(unexpectedToken(expected: "binding operator", got: opToken))
    } else {
      issues.append(unexpectedToken(expected: "binding operator"))
      return nil
    }

    // Parse the assigned expression.
    consumeNewlines()
    let expr = parseExpr(issues: &issues)
      ?? InvalidExpr(module: module, range: opIdent.range)
    return (op: opIdent, value: expr)
  }

}
