import AST

extension Parser {

  /// Parses a single statement.
  func parseStatement() throws -> Node {
    switch peek().kind {
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
          attributes.insert(.static)
        case .let, .var, .fun:
          break attrs
        default:
          throw unexpectedToken(expected: "property of function declaration")
        }
      }

      // The next consummable token should be `let`, `var` or `fun`.
      let decl = try parseStatement()
      decl.range = SourceRange(from: startToken.range.start, to: decl.range.end)
      if let propDecl = decl as? PropDecl {
        propDecl.attributes.formUnion(attributes)
      } else if let funDecl = decl as? FunDecl {
        funDecl.attributes.formUnion(attributes)
      } else {
        assertionFailure()
      }

      return decl

    case .let, .var:
      return try parsePropDecl()
    case .fun:
      return try parseFunDecl()
    case .struct:
      return try parseStructDecl()
    case .interface:
      return try parseInterfaceDecl()
    case .return:
      return try parseReturnStmt()
    default:
      // Attempt to parse a binding statement before falling back to an expression.
      if let binding = attempt(parseBindingStmt) {
        return binding
      }
      return try parseExpression()
    }
  }

  /// Parses a block of statements, delimited by braces.
  func parseStatementBlock() throws -> Block {
    guard let startToken = consume(.leftBrace)
      else { throw unexpectedToken(expected: "{") }

    // Skip trailing new lines.
    consumeNewlines()

    // Parse as many statements as possible
    var statements: [Node] = []
    while peek().kind != .rightBrace {
      statements.append(try parseStatement())

      // If the next token isn't the block delimiter, we MUST parse a statement delimiter.
      if peek().kind != .rightBrace {
        guard peek().isStatementDelimiter
          else { throw parseFailure(.expectedStatementDelimiter) }
        consumeNewlines()
      }
    }

    let endToken = consume(.rightBrace)!
    return Block(
      statements: statements,
      module: module,
      range: SourceRange(from: startToken.range.start, to: endToken.range.end))
  }

  /// Parses a return statement.
  func parseReturnStmt() throws -> ReturnStmt {
    guard let startToken = consume(.return)
      else { throw unexpectedToken(expected: "return") }

    // Parse an optional return value.
    if let value = attempt(parseExpression) {
      return ReturnStmt(
        value: value,
        module: module,
        range: SourceRange(from: startToken.range.start, to: value.range.end))
    } else {
      return ReturnStmt(
        module: module,
        range: startToken.range)
    }
  }

  /// Parses a binding statement.
  func parseBindingStmt() throws -> BindingStmt {
    // Parse the left operand.
    let left = try parseExpression()

    // Parse the binding operator.
    consumeNewlines()
    guard let op = peek().asBindingOperator
      else { throw unexpectedToken(expected: "binding operator") }
    consume()

    // Parse the right operand.
    consumeNewlines()
    let right = try parseExpression()
    return BindingStmt(
      lvalue: left,
      op: op,
      rvalue: right,
      module: module,
      range: SourceRange(from: left.range.start, to: right.range.end))
  }

}
