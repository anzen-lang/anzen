import AST

extension Parser {

  /// Parses a single top-level expression, statement or declaration.
  func parseTopLevelNode() -> Result<ASTNode?> {
    switch peek().kind {
    case .directive:
      // Compiler directives are currently parsed, but not supported. In the future, these will be
      // serve to control the parser's state, for instance to implement conditional compilation.
      let parseResult = parseDirective()
      if let directive = parseResult.value {
        let issue = parseFailure(.invalidDirective(directive: directive), range: directive.range)
        return Result(value: nil, issues: parseResult.issues + [issue])
      } else {
        return Result(value: nil, issues: parseResult.issues)
      }

    case .static, .mutating:
      // If the statement starts with a declaration modifier, it can describe either a property or
      // a function declaration. Hence we need to parse all modifiers before we can desambiguise.
      let head = peek()
      var modifiers: [DeclModifier] = []

      repeat {
        let declKind: DeclModifier.Kind = consume()!.kind == .static
          ? .static
          : .mutating
        modifiers.append(DeclModifier(kind: declKind, module: module, range: head.range))
        consumeNewlines()
      } while (peek().kind == .static) || (peek().kind == .mutating)

      // The next construction has to be a property or a function declaration. Nonetheless, we will
      // parse any statement or declaration anyway for the sake of error reporting.
      let parseResult = parseTopLevelNode()
      switch parseResult.value {
      case nil:
        return Result(value: nil, issues: parseResult.issues)

      case let decl as PropDecl:
        decl.modifiers = Set(modifiers)
        decl.range = modifiers.first!.range.lowerBound ..< decl.range.upperBound
        return Result(value: decl, issues: parseResult.issues)

      case let decl as FunDecl:
        decl.modifiers = Set(modifiers)
        decl.range = modifiers.first!.range.lowerBound ..< decl.range.upperBound
        return Result(value: decl, issues: parseResult.issues)

      case .some(let node):
        let issue = parseFailure(
          .unexpectedConstruction(expected: "property or function declaration", got: node),
          range: node.range)
        return Result(value: parseResult.value, issues: parseResult.issues + [issue])
      }

    case .let, .var:
      let parseResult = parsePropDecl()
      return Result(value: parseResult.value, issues: parseResult.issues)

    case .fun, .new, .del:
      let parseResult = parseFunDecl()
      return Result(value: parseResult.value, issues: parseResult.issues)

    case .interface:
      let parseResult = parseInterfaceDecl()
      return Result(value: parseResult.value, issues: parseResult.issues)

    case .struct:
      let parseResult = parseStructDecl()
      return Result(value: parseResult.value, issues: parseResult.issues)

    case .union:
      let parseResult = parseUnionDecl()
      return Result(value: parseResult.value, issues: parseResult.issues)

    case .case:
      let parseResult = parseUnionNestedMemberDecl()
      return Result(value: parseResult.value, issues: parseResult.issues)

    case .if:
      let parseResult = parseIfStmt()
      return Result(value: parseResult.value, issues: parseResult.issues)

    case .while:
      let parseResult = parseWhileStmt()
      return Result(value: parseResult.value, issues: parseResult.issues)

    case .return:
      let parseResult = parseReturnStmt()
      return Result(value: parseResult.value, issues: parseResult.issues)

    default:
      // Parse an expression.
      let lhsParseResult = parseExpr()
      let issues = lhsParseResult.issues

      if let lhs = lhsParseResult.value {
        // Attempt to parse a return binding.
        let opToken = peek(afterMany: .newline)
        if (opToken!.isBindingOperator || opToken!.kind == .assign) {
          consumeNewlines()
          let bindingParseResult = parseBinding()
          if let binding = bindingParseResult.value {
            let stmt = BindingStmt(
              op: binding.op,
              lvalue: lhs,
              rvalue: binding.value,
              module: module,
              range: lhs.range.lowerBound ..< binding.value.range.upperBound)
            return Result(value: stmt, issues: issues + bindingParseResult.issues)
          } else {
            return Result(value: lhs, issues: issues + bindingParseResult.issues)
          }
        }
      }
      return Result(value: lhsParseResult.value, issues: issues)
    }
  }

  /// Parses a brace statement.
  ///
  /// This parser recognizes a sequence of statements (in the broad sense), separated by statement
  /// delimiters (i.e. a newline or `;`) and enclosed in braces. In case of failure to parse a
  /// particular statement, the method tries to recover at the next delimiter.
  ///
  /// - SeeAlso: `parseCommaSeparatedList(delimitedBy:parsingElementWith:)`
  func parseBraceStmt() -> Result<BraceStmt?> {
    // The first token should be a left brace.
    guard let head = consume(.leftBrace)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "'{'")]) }

    var nodes: [ASTNode] = []
    var issues: [Issue] = []

    // Parse as many nodes as possible.
    while peek().kind != .rightBrace {
      // Skip leading new lines in front of the next statement to avoid triggering an error if the
      // end of the sequence has been reached.
      consumeNewlines()
      guard (peek().kind != .rightBrace) && (peek().kind != .eof)
        else { break }

      // Parse the next node.
      let nodeParseResult = parseTopLevelNode()
      issues.append(contentsOf: nodeParseResult.issues)
      if let node = nodeParseResult.value {
        nodes.append(node)
      } else {
        // If the next node couldn't be parsed, skip all input until the next statement delimiter.
        consumeUpToNextStatementDelimiter()
      }

      if peek().kind != .rightBrace {
        // If the next token isn't a closing brace nor the end of file, we **must** parse a
        // statement delimiter. Otherwise, we assume one is missing and attempt to parse the next
        // statement after raising an issue.
        guard peek().isStatementDelimiter || (peek().kind == .eof) else {
          issues.append(parseFailure(.expectedStatementDelimiter, range: peek().range))
          continue
        }
      }
    }

    let tail = consume(.leftBrace) ?? peek()
    assert(tail.kind == .leftBrace || tail.kind == .eof)
    if tail.kind == .eof {
      issues.append(unexpectedToken(expected: "'}'"))
    }

    let stmt = BraceStmt(
      stmts: nodes,
      module: module,
      range: head.range.lowerBound ..< tail.range.upperBound)
    return Result(value: stmt, issues: issues)
  }

  /// Parses a conditional expression.
  func parseIfStmt() -> Result<IfStmt?> {
    // The first token should be `if`.
    guard let head = consume(.if)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "'if'")]) }

    // Parse the statement's condition.
    consumeNewlines()
    let conditionParseResult = parseExpr()
    var issues = conditionParseResult.issues

    let condition: Expr
    if let expr = conditionParseResult.value {
      condition = expr
    } else {
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
        return Result(value: nil, issues: issues)
      }

      // Create an invalid expression placeholder for the condition.
      condition = InvalidExpr(module: module, range: head.range)
    }

    // Parse the statement's "then" body.
    consumeNewlines()
    let thenStmtParseResult = parseBraceStmt()
    issues.append(contentsOf: thenStmtParseResult.issues)

    var elseStmt: Stmt?
    if consume(.else, afterMany: .newline) != nil {
      // Commit to parse the statement's "else" node. This should be either an `if` statement, or
      // a brace statement.
      consumeNewlines()
      switch peek().kind {
      case .if:
        let elseStmtParseResult = parseIfStmt()
        issues.append(contentsOf: elseStmtParseResult.issues)
        elseStmt = elseStmtParseResult.value

      case .leftBrace:
        let elseStmtParseResult = parseBraceStmt()
        issues.append(contentsOf: elseStmtParseResult.issues)
        elseStmt = elseStmtParseResult.value

      default:
        issues.append(unexpectedToken(expected: "'{'"))
      }
    }

    // We can't produce a valid statement if either its condition or body couldn't be parsed
    // successfully. Nonetheless we'll produce a "fake" one so that semantic analysis can run on
    // whathever we were able to parse.
    let thenStmt: Stmt = thenStmtParseResult.value
      ?? InvalidStmt(module: module, range: head.range)
    let stmt = IfStmt(
      condition: condition,
      thenStmt: thenStmt,
      elseStmt: elseStmt,
      module: module,
      range: head.range.lowerBound ..< (elseStmt ?? thenStmt).range.upperBound)
    return Result(value: stmt, issues: issues)
  }

  /// Parses a while-loop.
  func parseWhileStmt() -> Result<WhileStmt?> {
    // The first token should be `while`.
    guard let head = consume(.while)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "'while'")]) }

    // Parse the loop's condition.
    consumeNewlines()
    let conditionParseResult = parseExpr()
    var issues = conditionParseResult.issues

    let condition: Expr
    if let expr = conditionParseResult.value {
      condition = expr
    } else {
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
        return Result(value: nil, issues: issues)
      }

      // Create an invalid expression placeholder for the condition.
      condition = InvalidExpr(module: module, range: head.range)
    }

    // Parse the loop's body.
    consumeNewlines()
    let bodyParseResult = parseBraceStmt()
    issues.append(contentsOf: bodyParseResult.issues)

    // We can't produce a valid statement if either its condition or body couldn't be parsed
    // successfully. Nonetheless we'll produce a "fake" one so that semantic analysis can run on
    // whathever we were able to parse.
    let body: Stmt = bodyParseResult.value
      ?? InvalidStmt(module: module, range: head.range)
    let stmt = WhileStmt(
      condition: condition,
      body: body,
      module: module,
      range: head.range.lowerBound ..< body.range.upperBound)
    return Result(value: stmt, issues: issues)
  }

  /// Parses a return statement.
  func parseReturnStmt() -> Result<ReturnStmt?> {
    // The first token should be `return`.
    guard let head = consume(.return)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "'return'")]) }

    // Attempt to parse a return binding.
    var binding: (IdentExpr, Expr)?
    var issues: [Issue] = []
    var rangeUpperBound = head.range.upperBound

    let opToken = peek(afterMany: .newline)
    if (opToken!.isBindingOperator || opToken!.kind == .assign) {
      consumeNewlines()
      let parseResult = parseBinding()
      issues.append(contentsOf: parseResult.issues)
      if let parsedBinding = parseResult.value {
        binding = parsedBinding
        rangeUpperBound = parsedBinding.value.range.upperBound
      }
    }

    let stmt = ReturnStmt(
      binding: binding,
      module: module,
      range: head.range.lowerBound ..< rangeUpperBound)
    return Result(value: stmt, issues: issues)
  }

  /// Parses the right side of a binding (i.e. a binding operator with an r-value).
  func parseBinding() -> Result<(op: IdentExpr, value: Expr)?> {
    // Parse the binding operator.
    guard let opToken = consume(if: { $0.isBindingOperator }) else {
      if let opToken = consume(.assign) {
        // Catch invalid uses of the "assign" token in lieu of a binding operator.
        let issue = parseFailure(
          .unexpectedToken(expected: "binding operator", got: opToken),
          range: opToken.range)

        // Parse the expression in case it contains syntax issues as well.
        consumeNewlines()
        let parseResult = parseExpr()
        return Result(value: nil, issues: parseResult.issues + [issue])
      } else {
        return Result(value: nil, issues: [unexpectedToken(expected: "binding operator")])
      }
    }

    // Parse the right operand.
    consumeNewlines()
    let parseResult = parseExpr()
    if let rhs = parseResult.value {
      let opIdent = IdentExpr(name: opToken.value!, module: module, range: opToken.range)
      return Result(value: (opIdent, rhs), issues: parseResult.issues)
    } else {
      return Result(value: nil, issues: parseResult.issues)
    }
  }

  /// Parses a compiler directive.
  func parseDirective() -> Result<Directive?> {
    // The first token should be a directive (i.e. `'#' <ident>`).
    guard let head = consume(.directive)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "directive")]) }

    // Attempt to parse an argument list on the same line.
    var args: [Token] = []
    var issues: [Issue] = []
    var rangeUpperBound = head.range.upperBound

    if consume(.leftParen) != nil {
      // Commit to parse an argument list.
      let argsParseResult = parseCommaSeparatedList(
        delimitedBy: .rightParen,
        parsingElementWith: parseDirectiveArg)

      args = argsParseResult.value
      if let delimiter = consume(.rightParen) {
        rangeUpperBound = delimiter.range.upperBound
      } else {
        rangeUpperBound = args.last?.range.upperBound ?? rangeUpperBound
        issues.append(unexpectedToken(expected: "')'"))
      }
    }

    let directive = Directive(
      name: head.value!,
      args: args.map { $0.value! },
      module: module,
      range: head.range.lowerBound ..< rangeUpperBound)
    return Result(value: directive, issues: issues)
  }

  func parseDirectiveArg() -> Result<Token?> {
    if let arg = consume(.identifier) {
      return Result(value: arg, issues: [])
    } else {
      return Result(value: nil, issues: [unexpectedToken(expected: "identifier")])
    }
  }

}
