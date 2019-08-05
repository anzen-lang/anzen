import AST
import Utils

let exprStartTokens: Set<TokenKind> = [
  .identifier, .nullref, .bool, .integer, .float, .string, .fun, .dot,
  .leftParen, .leftBracket, .leftBrace,
]

extension Parser {

  /// Parses an expression.
  ///
  /// Use this parse method as the entry point to parse any Anzen expression.
  ///
  /// Because this parser is implemented as a recursive descent parser, a particular attention must
  /// be made as to how expressions can be parsed witout triggering infinite recursions, due to the
  /// left-recursion of the related production rules.
  func parseExpr() -> Result<Expr?> {
    // Parse the left operand.
    let atomParseResult = parseAtom()
    var issues = atomParseResult.issues

    guard var expr = atomParseResult.value
      else { return Result(value: nil, issues: issues) }

    // Attempt to parse the remainder of a binary expression.
    while true {
      // Attempt to consume an infix operator.
      guard let infixToken = consume(if: { $0.isInfixOperator }, afterMany: .newline)
        else { break }
      consumeNewlines()

      // Build the infix operator's identifier.
      let infixIdent = IdentExpr(
        name: infixToken.kind.description,
        module: module,
        range: infixToken.range)

      if infixToken.kind == .as {
        // If the infix token is a cast operator (e.g. `as`), then the right operand should be
        // parsed as an unqualified type signature rather than an expression.
        let rhsParseResult = parseTypeSign()
        issues.append(contentsOf: rhsParseResult.issues)
        let rhs: TypeSign
        if rhsParseResult.value != nil {
          rhs = rhsParseResult.value!
        } else {
          recoverAtNextStatementDelimiter()
          rhs = InvalidSign(module: module, range: infixToken.range)
        }

        // Apply some grammar disambiguation rules.
        switch expr {
        case is UnsafeCastExpr:
          issues.append(parseFailure(
            .nonAssociativeOperator(op: infixToken.kind.description), range: infixToken.range))

        case is InfixExpr:
          issues.append(parseFailure(.ambiguousCastOperand, range: infixToken.range))

        default:
          break
        }

        // Add the right operand to the left hand side expression.
        expr = UnsafeCastExpr(
          operand: expr,
          castSign: rhs,
          module: module,
          range: expr.range.lowerBound ..< rhs.range.upperBound)
      } else {
        // For any other operators, the right operand should be parsed as an expression.
        let rhsParseResult = parseAtom()
        issues.append(contentsOf: rhsParseResult.issues)
        let rhs: Expr
        if rhsParseResult.value != nil {
          rhs = rhsParseResult.value!
        } else {
          recoverAtNextStatementDelimiter()
          rhs = InvalidExpr(module: module, range: infixToken.range)
        }

        // Add the right operand to the left hand side expression.
        expr = addAdjacentInfixExpr(
          lhs: expr,
          op: infixIdent,
          precedenceGroup: Parser.precedenceGroups[infixToken.kind]!,
          rhs: rhs,
          issues: &issues)
      }
    }

    return Result(value: expr, issues: issues)
  }

  /// Helper method to properly parse adjacent infix expressions.
  private func addAdjacentInfixExpr(
    lhs: Expr,
    op: IdentExpr,
    precedenceGroup: InfixExpr.PrecedenceGroup,
    rhs: Expr,
    issues: inout [Issue]) -> InfixExpr
  {
    if let infixLHS = lhs as? InfixExpr {
      // If the left operator is an infix expression, check whether we should rebind its right hand
      // side operand to the right-most operator.
      var shouldBindRight = false
      if infixLHS.op.name == op.name {
        // Check associativity to resolve identical adjacent operators.
        switch precedenceGroup.associativity {
        case .none:
          issues.append(parseFailure(.nonAssociativeOperator(op: op.name), range: op.range))
        case .right:
          shouldBindRight = true
        case .left:
          break
        }
      } else if infixLHS.precedenceGroup.precedence < precedenceGroup.precedence {
        // Check associativity to resolve other adjacent operators.
        shouldBindRight = true
      }

      if shouldBindRight {
        let newRHS = addAdjacentInfixExpr(
          lhs: infixLHS.rhs,
          op: op,
          precedenceGroup: precedenceGroup,
          rhs: rhs,
          issues: &issues)

        return InfixExpr(
          op: infixLHS.op,
          precedenceGroup: infixLHS.precedenceGroup,
          lhs: infixLHS.lhs,
          rhs: newRHS,
          module: module,
          range: lhs.range.lowerBound ..< rhs.range.upperBound)
      }
    }

    // Bind a left-associative operator.
    return InfixExpr(
      op: op,
      precedenceGroup: precedenceGroup,
      lhs: lhs,
      rhs: rhs,
      module: module,
      range: lhs.range.lowerBound ..< rhs.range.upperBound)
  }

  /// Parses an atom.
  func parseAtom() -> Result<Expr?> {
    let token = peek()
    let startLocation = token.range.lowerBound

    var expr: Expr
    var issues: [Issue] = []

    switch token.kind {
    case .nullref:
      consume()
      expr = NullExpr(module: module, range: token.range)

    case .bool:
      consume()
      expr = BoolLitExpr(value: token.value == "true", module: module, range: token.range)

    case .integer:
      consume()
      expr = IntLitExpr(value: Int(token.value!)!, module: module, range: token.range)

    case .float:
      consume()
      expr = FloatLitExpr(value: Double(token.value!)!, module: module, range: token.range)

    case .string:
      consume()
      expr = StrLitExpr(value: token.value!, module: module, range: token.range)

    case _ where token.isPrefixOperator:
      let parseResult = parsePrefixExpr()
      issues = parseResult.issues
      guard let node = parseResult.value
        else { return Result(value: nil, issues: issues) }
      expr = node

    case .identifier:
      let parseResult = parseIdentExpr()
      issues = parseResult.issues
      guard let node = parseResult.value
        else { return Result(value: nil, issues: issues) }
      expr = node

    case .fun:
      let parseResult = parseLambdaExpr()
      issues = parseResult.issues
      guard let node = parseResult.value
        else { return Result(value: nil, issues: issues) }
      expr = node

    case .leftBracket:
      let parseResult = parseArrayLitExpr()
      issues = parseResult.issues
      guard let node = parseResult.value
        else { return Result(value: nil, issues: issues) }
      expr = node

    case .leftBrace:
      let parseResult = parseMapOrSetLitExpr()
      issues = parseResult.issues
      guard let node = parseResult.value
        else { return Result(value: nil, issues: issues) }
      expr = node

    case .dot:
      consume()
      let parseResult = parseIdentExpr(allowOperators: true)
      issues = parseResult.issues
      guard let ident = parseResult.value
        else { return Result(value: nil, issues: issues) }
      expr = ImplicitSelectExpr(
        ownee: ident,
        module: module,
        range: startLocation ..< ident.range.upperBound)

    case .leftParen:
      consume()
      consumeNewlines()
      let parseResult = parseExpr()
      issues = parseResult.issues
      guard let enclosed = parseResult.value
        else { return Result(value: nil, issues: issues) }

      let delimiter = consume(.rightParen, afterMany: .newline)
      if delimiter == nil {
        issues.append(unexpectedToken(expected: "')'"))
      }

      let upperBound = delimiter?.range.upperBound ?? enclosed.range.upperBound
      expr = ParenExpr(
        enclosing: enclosed,
        module: module,
        range: startLocation ..< upperBound)

    default:
      return Result(value: nil, issues: [unexpectedToken(expected: "expression")])
    }

    // Implementation note:
    // Although it wouldn't make the grammar ambiguous otherwise, notice that we require trailers
    // to start at the same line. The rationale is that it doing otherwise could easily make some
    // portions of code *look* ambiguous.

    trailer:while true {
      if let head = consume([.leftParen, .leftBracket]) {
        let delimiter: TokenKind = head.kind == .leftParen
          ? .rightParen
          : .rightBracket
        let parseResult = parseCommaSeparatedList(delimitedBy: delimiter, with: parseCallArgExpr)
        issues.append(contentsOf: parseResult.issues)

        // Consume the delimiter of the list.
        let endToken = consume(delimiter)
        if endToken == nil {
          issues.append(unexpectedToken(expected: "'\(delimiter)'"))
        }
        let rangeUpperBound = endToken?.range.upperBound ?? expr.range.upperBound

        let callee: Expr
        if head.kind == .leftParen {
          callee = expr
        } else {
          callee = SelectExpr(
            owner: expr,
            ownee: IdentExpr(name: "[]", module: module, range: expr.range),
            module: module,
            range: expr.range)
        }

        expr = CallExpr(
          callee: callee,
          args: parseResult.value,
          module: module,
          range: expr.range.lowerBound ..< rangeUpperBound)

        continue trailer
      }

      // Consuming new lines here allow us to parse select expressions split over several lines.
      // However, if the next consumable token isn't a dot, we need to backtrack, so as to avoid
      // consuming possibly significant new lines.
      let savePoint = streamPosition
      if consume(.dot, afterMany: .newline) != nil {
        let identParseResult = parseIdentExpr(allowOperators: true)
        issues.append(contentsOf: identParseResult.issues)
        guard let ident = identParseResult.value
          else { return Result(value: expr, issues: issues) }

        expr = SelectExpr(
          owner: expr,
          ownee: ident,
          module: module,
          range: expr.range.lowerBound ..< ident.range.upperBound)

        continue trailer
      }

      // No more trailer to parse.
      rewind(to: savePoint)
      break
    }

    return Result(value: expr, issues: issues)
  }

  /// Parses a prefix expression.
  func parsePrefixExpr() -> Result<PrefixExpr?> {
    // The first token must be an unary operator.
    guard let opToken = consume(if: { $0.isPrefixOperator })
      else { return Result(value: nil, issues: [unexpectedToken(expected: "unary operator")]) }

    // Parse the expression.
    let parseResult = parseExpr()
    let operand: Expr

    if parseResult.value != nil {
      operand = parseResult.value!
    } else {
      operand = InvalidExpr(module: module, range: opToken.range)

      // Look for a recovery point.
      let recoveryKinds = exprStartTokens.union([.newline, .semicolon, .eof])
      consumeMany { !recoveryKinds.contains($0.kind) }
    }

    let expr = PrefixExpr(
      op: IdentExpr(name: opToken.kind.description, module: module, range: opToken.range),
      operand: operand,
      module: module,
      range: opToken.range.lowerBound ..< operand.range.upperBound)
    return Result(value: expr, issues: parseResult.issues)
  }

  /// Parses an identifier.
  func parseIdentExpr(allowOperators: Bool = false) -> Result<IdentExpr?> {
    let ident: IdentExpr
    var issues: [Issue] = []

    // The first token is either an identifier or an operator (provided `allowsOperator` is set).
    if let name = consume(.identifier) {
      ident = IdentExpr(name: name.value!, module: module, range: name.range)
    } else if allowOperators, let op = consume(if: { $0.isPrefixOperator || $0.isInfixOperator }) {
      ident = IdentExpr(name: op.kind.description, module: module, range: op.range)
    } else {
      return Result(value: nil, issues: [unexpectedToken(expected: "identifier")])
    }

    // Attempt to parse a specialization list.
    let parseResult = parseSpecArgs()
    if parseResult != nil {
      issues.append(contentsOf: parseResult!.issues)
      ident.specArgs = parseResult!.value.list
      ident.range = ident.range.lowerBound ..< parseResult!.value.range.upperBound
    }
    return Result(value: ident, issues: issues)
  }

  /// Parses a lambda expression.
  func parseLambdaExpr() -> Result<LambdaExpr?> {
    // The first token should be `fun`.
    guard let head = consume(.fun)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "'fun'")]) }

    var issues: [Issue] = []

    /// Attempt to parse a parameter list.
    var params: [ParamDecl] = []
    if consume(.leftParen, afterMany: .newline) != nil {
      let parseResult = parseCommaSeparatedList(delimitedBy: .rightParen, with: parseParamDecl)
      params = parseResult.value
      issues.append(contentsOf: parseResult.issues)

      // Make sure there are no duplicate parameters.
      var paramNames: Set<String> = []
      for param in parseResult.value {
        if paramNames.contains(param.name) {
          issues.append(parseFailure(.duplicateParameter(name: param.name), range: param.range))
        }
        paramNames.insert(param.name)
      }

      if consume(.rightParen, afterMany: .newline) == nil {
        issues.append(unexpectedToken(expected: "')'"))
      }
    }

    // Attempt to parse a codomain.
    var codom: QualTypeSign?
    if consume(.arrow, afterMany: .newline) != nil {
      consumeNewlines()
      let signParseResult = parseQualSign()
      issues.append(contentsOf: signParseResult.issues)

      if let sign = signParseResult.value {
        codom = sign
      } else {
        consumeMany { !$0.isStatementDelimiter && ($0.kind != .leftBrace) && ($0.kind != .eof) }
      }
    }

    // Parse a function body.
    consumeNewlines()
    let bodyParseResult = parseBraceStmt()
    issues.append(contentsOf: bodyParseResult.issues)

    let body: Stmt
    if bodyParseResult.value != nil {
      body = bodyParseResult.value!
    } else {
      body = InvalidStmt(module: module, range: peek().range)
    }

    let expr = LambdaExpr(
      params: params,
      codom: codom,
      body: body,
      module: module,
      range: head.range.lowerBound ..< body.range.upperBound)
    return Result(value: expr, issues: issues)
  }

  /// Parses a call argument.
  func parseCallArgExpr() -> Result<CallArgExpr?> {
    // Attempt to parse an explicit parameter assignment (i.e. `label operator expression`).
    let savePoint = streamPosition
    if let token = consume(.identifier) {
      // Attempt to parse a binding operator.
      if let opToken = consume(if: { $0.isBindingOperator }, afterMany: .newline) {
        // Commit to parsing an explicit parameter assignment (i.e. `label operator expression`).
        consumeNewlines()
        let parseResult = parseExpr()

        let value: Expr
        if parseResult.value != nil {
          value = parseResult.value!
        } else {
          value = InvalidExpr(module: module, range: opToken.range)

          // Look for a recovery point.
          let recoveryKinds = exprStartTokens.union([.newline, .semicolon, .eof])
          consumeMany { !recoveryKinds.contains($0.kind) }
        }

        let expr = CallArgExpr(
          label: token.value,
          op: IdentExpr(name: opToken.kind.description, module: module, range: opToken.range),
          value: value,
          module: module,
          range: token.range.lowerBound ..< value.range.upperBound)
        return Result(value: expr, issues: parseResult.issues)
      } else {
        // If we couldn't parse the remainder of an explicit parameter assignment, we rewind an
        // attempt to parse a simple expression instead.
        rewind(to: savePoint)
      }
    }

    // Parse the argument's value.
    let parseResult = parseExpr()
    guard let value = parseResult.value
      else { return Result(value: nil, issues: parseResult.issues) }

    let expr = CallArgExpr(
      op: IdentExpr(name: ":=", module: module, range: value.range),
      value: value,
      module: module,
      range: value.range)
    return Result(value: expr, issues: parseResult.issues)
  }

  /// Parses an array literal.
  func parseArrayLitExpr() -> Result<ArrayLitExpr?> {
    // The first token must be left bracket.
    guard let head = consume(.leftBracket)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "'['")]) }

    // Parse the array elements.
    let parseResult = parseCommaSeparatedList(delimitedBy: .rightBracket, with: parseExpr)
    let elems = parseResult.value
    var issues = parseResult.issues

    // Parse the expression's delimiter.
    let endToken = consume(.rightBracket)
    if endToken == nil {
      issues.append(unexpectedToken(expected: "']'"))
      recoverAtNextStatementDelimiter()
    }

    let rangeUpperBound = (endToken?.range ?? elems.last?.range ?? head.range).upperBound
    let expr = ArrayLitExpr(
      elems: elems,
      module: module,
      range: head.range.lowerBound ..< rangeUpperBound)
    return Result(value: expr, issues: issues)
  }

  /// Parses a map or set literal.
  ///
  /// Map and set liteals are similar in that they are a list of elements enclosed in braces, which
  /// complicates error reporting. We choose to commit on whether we're parsing a map or a set
  /// literal based on the successful parsing of the first element.
  ///
  /// Note that a colon is required to distinguish between empty set literals and map literals, so
  /// that `{}` is parsed as an empty set literal and `{:}` is parser as the empty map literal.
  func parseMapOrSetLitExpr() -> Result<Expr?> {
    // The first token must be brace bracket.
    guard let head = consume(.leftBrace)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "'{'")]) }
    var issues: [Issue] = []

    // If the next consumable token is the right delimiter, we've got an empty set literal.
    if let endToken = consume(.rightBrace, afterMany: .newline) {
      let expr = SetLitExpr(
        elems: [],
        module: module,
        range: head.range.lowerBound ..< endToken.range.upperBound)
      return Result(value: expr, issues: [])
    }

    // If the next consumable token is a colon, we've probably got an empty map literal.
    if consume(.colon, afterMany: .newline) != nil {
      // Commit to parsing the empty map literal.
      let endToken = consume(.rightBrace)
      if endToken == nil {
        issues.append(unexpectedToken(expected: "']'"))
        recoverAtNextStatementDelimiter()
      }

      let rangeUpperBound = (endToken?.range ?? head.range).upperBound
      let expr = MapLitExpr(
        elems: [:],
        module: module,
        range: head.range.lowerBound ..< rangeUpperBound)
      return Result(value: expr, issues: issues)
    }

    // Attempt to parse a map element.
    consumeNewlines()
    let savePoint = streamPosition
    let firstMapElementParseResult = parseMapElem()
    rewind(to: savePoint)

    if firstMapElementParseResult.value != nil {
      // Commit to parsing a map literal.
      let mapElemsParseResult = parseMapElems()
      let elems = mapElemsParseResult.value
      issues.append(contentsOf: mapElemsParseResult.issues)

      let endToken = consume(.rightBrace)
      let rangeUpperBound: SourceLocation
      if endToken == nil {
        rangeUpperBound = elems.values.map({ $0.range.upperBound }).max() ?? head.range.upperBound
        issues.append(unexpectedToken(expected: "']'"))
        recoverAtNextStatementDelimiter()
      } else {
        rangeUpperBound = endToken!.range.upperBound
      }

      let expr = MapLitExpr(
        elems: elems,
        module: module,
        range: head.range.lowerBound ..< rangeUpperBound)
      return Result(value: expr, issues: issues)
    } else {
      // Commit to parsing a set literal.
      let setElemsParseResult = parseCommaSeparatedList(delimitedBy: .rightBrace, with: parseExpr)
      let elems = setElemsParseResult.value
      issues.append(contentsOf: setElemsParseResult.issues)

      let endToken = consume(.rightBrace)
      let rangeUpperBound: SourceLocation
      if endToken == nil {
        rangeUpperBound = elems.last?.range.upperBound ?? head.range.upperBound
        issues.append(unexpectedToken(expected: "']'"))
        recoverAtNextStatementDelimiter()
      } else {
        rangeUpperBound = endToken!.range.upperBound
      }

      let expr = SetLitExpr(
        elems: elems,
        module: module,
        range: head.range.lowerBound ..< rangeUpperBound)
      return Result(value: expr, issues: issues)
    }
  }

  /// Parses a sequence of key/value pairs as the elements of a map literal.
  func parseMapElems() -> Result<[String: Expr]> {
    // Parse the map elements.
    let parseResult = parseCommaSeparatedList(delimitedBy: .rightBrace, with: parseMapElem)
    var issues = parseResult.issues

    var elems: [String: Expr] = [:]
    for (token, value) in parseResult.value {
      // Make sure there are no duplicate keys.
      guard elems[token.value!] == nil else {
        issues.append(parseFailure(.duplicateKey(key: token.value!), range: token.range))
        continue
      }
      elems[token.value!] = value
    }

    return Result(value: elems, issues: issues)
  }

  /// Parses a map literal element.
  func parseMapElem() -> Result<(Token, Expr)?> {
    // Parse the key of the element.
    guard let key = consume(.identifier)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "identifier")]) }

    // Parse the value of the element.
    guard consume(.colon, afterMany: .newline) != nil else {
      defer { recoverAtNextStatementDelimiter() }
      return Result(value: nil, issues: [unexpectedToken(expected: "':'")])
    }

    consumeNewlines()
    let parseResult = parseExpr()
    guard let value = parseResult.value
      else { return Result(value: nil, issues: parseResult.issues) }

    return Result(value: (key, value), issues: parseResult.issues)
  }

}
