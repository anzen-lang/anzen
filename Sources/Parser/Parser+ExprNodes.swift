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
  func parseExpr(issues: inout [Issue]) -> Expr? {
    // Parse the left operand.
    guard var expr = parseAtom(issues: &issues)
      else { return nil }

    // Attempt to parse the remainder of a binary expression.
    while true {
      // Attempt to consume an infix operator.
      guard let infixToken = consume(if: { $0.isInfixOperator }, afterMany: .newline)
        else { break }
      consumeNewlines()

      // Build the infix operator's identifier.
      let infixIdent = IdentExpr(name: infixToken.value!, module: module, range: infixToken.range)

      if infixToken.kind == .as {
        // If the infix token is a cast operator (e.g. `as`), then the right operand should be
        // parsed as an unqualified type signature rather than an expression.
        var rhs = parseTypeSign(issues: &issues)
        if rhs == nil {
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
          castSign: rhs!,
          module: module,
          range: expr.range.lowerBound ..< rhs!.range.upperBound)
      } else {
        // For any other operators, the right operand should be parsed as an expression.
        var rhs = parseAtom(issues: &issues)
        if rhs == nil {
          recoverAtNextStatementDelimiter()
          rhs = InvalidExpr(module: module, range: infixToken.range)
        }

        // Add the right operand to the left hand side expression.
        expr = addAdjacentInfixExpr(
          lhs: expr,
          op: infixIdent,
          precedenceGroup: Parser.precedenceGroups[infixToken.kind]!,
          rhs: rhs!,
          issues: &issues)
      }
    }

    return expr
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
  func parseAtom(issues: inout [Issue]) -> Expr? {
    let token = peek()

    var expr: Expr
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
      guard let node = parsePrefixExpr(issues: &issues)
        else { return nil }
      expr = node

    case .identifier:
      guard let node = parseIdentExpr(issues: &issues)
        else { return nil }
      expr = node

    case .fun:
      guard let node = parseLambdaExpr(issues: &issues)
        else { return nil }
      expr = node

    case .leftBracket:
      guard let node = parseArrayLitExpr(issues: &issues)
        else { return nil }
      expr = node

    case .leftBrace:
      guard let node = parseMapOrSetLitExpr(issues: &issues)
        else { return nil }
      expr = node

    case .dot:
      let head = consume()!
      let ownee = parseIdentExpr(includingOperators: true, issues: &issues)
      if ownee != nil {
        expr = ImplicitSelectExpr(
          ownee: ownee!,
          module: module,
          range: head.range.lowerBound ..< ownee!.range.upperBound)
      } else {
        expr = InvalidExpr(module: module, range: head.range)
      }

    case .leftParen:
      let head = consume()!
      consumeNewlines()
      var enclosed = parseExpr(issues: &issues)
      if enclosed == nil {
        enclosed = InvalidExpr(module: module, range: head.range)
        recover(atNextKinds: [.rightParen])
      }

      let delimiter = consume(.rightParen, afterMany: .newline)
      if delimiter == nil {
        issues.append(unexpectedToken(expected: "')'"))
      }

      let upperBound = delimiter?.range.upperBound ?? enclosed!.range.upperBound
      return ParenExpr(
        enclosing: enclosed!,
        module: module,
        range: head.range.lowerBound ..< upperBound)

    default:
      issues.append(unexpectedToken(expected: "expression"))
      return nil
    }

    // Implementation note:
    // Although it wouldn't make the grammar ambiguous otherwise, notice that we require trailers
    // to start at the same line. The rationale is that it doing otherwise could easily make some
    // portions of code *look* ambiguous.

    while true {
      if let head = consume([.leftParen, .leftBracket]) {
        let delimiter: TokenKind = head.kind == .leftParen
          ? .rightParen
          : .rightBracket
        let args = parseList(delimitedBy: delimiter, issues: &issues, with: parseCallArgExpr)

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
          args: args,
          module: module,
          range: expr.range.lowerBound ..< rangeUpperBound)
        continue
      }

      // Consuming new lines here allow us to parse select expressions split over several lines.
      if consume(.dot, afterMany: .newline) != nil {
        guard let ident = parseIdentExpr(includingOperators: true, issues: &issues)
          else { break }
        expr = SelectExpr(
          owner: expr,
          ownee: ident,
          module: module,
          range: expr.range.lowerBound ..< ident.range.upperBound)
        continue
      }

      // No more trailer to parse.
      break
    }

    return expr
  }

  /// Parses a prefix expression.
  func parsePrefixExpr(issues: inout [Issue]) -> PrefixExpr? {
    // The first token must be an unary operator.
    guard let opToken = consume(if: { $0.isPrefixOperator }) else {
      issues.append(unexpectedToken(expected: "unary operator"))
      return nil
    }

    // Parse the expression.
    let operand = parseExpr(issues: &issues)
      ?? InvalidExpr(module: module, range: opToken.range)

    return PrefixExpr(
      op: IdentExpr(name: opToken.kind.description, module: module, range: opToken.range),
      operand: operand,
      module: module,
      range: opToken.range.lowerBound ..< operand.range.upperBound)
  }

  /// Parses an identifier.
  func parseIdentExpr(includingOperators: Bool = false, issues: inout [Issue]) -> IdentExpr? {
    let ident: IdentExpr
    if let nameToken = consume(if: { ($0.kind | TokenKind.Category.name) != 0 }) {
      ident = IdentExpr(name: nameToken.value!, module: module, range: nameToken.range)
      if (nameToken.kind & TokenKind.Category.keyword) != 0 {
        issues.append(parseFailure(
          .keywordAsIdentifier(keyword: ident.name), range: nameToken.range))
      }
    } else {
      issues.append(unexpectedToken(expected: "identifier"))
      return nil
    }

    // Attempt to parse a specialization list.
    if let (specArgs, specArgsRange) = parseSpecArgs(issues: &issues) {
      ident.specArgs = specArgs
      ident.range = ident.range.lowerBound ..< specArgsRange.upperBound
    }

    return ident
  }

  /// Parses a lambda expression.
  func parseLambdaExpr(issues: inout [Issue]) -> LambdaExpr? {
    // The first token should be `fun`.
    guard let head = consume(.fun) else {
      issues.append(unexpectedToken(expected: "'fun'"))
      return nil
    }

    /// Attempt to parse a parameter list.
    var params: [ParamDecl] = []
    if consume(.leftParen, afterMany: .newline) != nil {
      params = parseList(delimitedBy: .rightParen, issues: &issues, with: parseParamDecl)
      if consume(.rightParen, afterMany: .newline) == nil {
        issues.append(unexpectedToken(expected: "')'"))
      }
    }

    // Attempt to parse a codomain.
    var codom: QualTypeSign?
    if consume(.arrow, afterMany: .newline) != nil {
      consumeNewlines()
      if let sign = parseQualSign(issues: &issues) {
        codom = sign
      } else {
        recover(atNextKinds: [.leftBrace, .newline])
      }
    }

    // Parse a function body.
    consumeNewlines()
    let body = parseBraceStmt(issues: &issues)
      ?? BraceStmt(stmts: [], module: module, range: head.range)

    return LambdaExpr(
      params: params,
      codom: codom,
      body: body,
      module: module,
      range: head.range.lowerBound ..< body.range.upperBound)
  }

  /// Parses a call argument.
  func parseCallArgExpr(issues: inout [Issue]) -> CallArgExpr? {
    // Attempt to parse an explicit parameter assignment (i.e. `label operator expression`).
    let savePoint = streamPosition
    if let token = consume(.identifier) {
      // Attempt to parse a binding operator.
      if let opToken = consume(if: { $0.isBindingOperator }, afterMany: .newline) {
        // Commit to parsing an explicit parameter assignment (i.e. `label operator expression`).
        consumeNewlines()
        let value = parseExpr(issues: &issues)
          ?? InvalidExpr(module: module, range: opToken.range)

        return CallArgExpr(
          label: token.value,
          op: IdentExpr(name: opToken.kind.description, module: module, range: opToken.range),
          value: value,
          module: module,
          range: token.range.lowerBound ..< value.range.upperBound)
      } else {
        // If we couldn't parse the remainder of an explicit parameter assignment, we rewind an
        // attempt to parse a simple expression instead.
        rewind(to: savePoint)
      }
    }

    // Parse the argument's value.
    guard let value = parseExpr(issues: &issues)
      else { return nil }
    return CallArgExpr(
      op: IdentExpr(name: ":=", module: module, range: value.range),
      value: value,
      module: module,
      range: value.range)
  }

  /// Parses an array literal.
  func parseArrayLitExpr(issues: inout [Issue]) -> ArrayLitExpr? {
    // The first token must be left bracket.
    guard let head = consume(.leftBracket) else {
      issues.append(unexpectedToken(expected: "'['"))
      return nil
    }

    // Parse the array elements.
    let elems = parseList(delimitedBy: .rightBracket, issues: &issues, with: parseExpr)

    // Parse the expression's delimiter.
    let endToken = consume(.rightBracket)
    if endToken == nil {
      issues.append(unexpectedToken(expected: "']'"))
    }

    let rangeUpperBound = (endToken?.range ?? elems.last?.range ?? head.range).upperBound
    return ArrayLitExpr(
      elems: elems,
      module: module,
      range: head.range.lowerBound ..< rangeUpperBound)
  }

  /// Parses a map or set literal.
  ///
  /// Map and set liteals are similar in that they are a list of elements enclosed in braces, which
  /// complicates error reporting. We choose to commit on whether we're parsing a map or a set
  /// literal based on the successful parsing of the first element.
  ///
  /// Note that a colon is required to distinguish between empty set literals and map literals, so
  /// that `{}` is parsed as an empty set literal and `{:}` is parser as the empty map literal.
  func parseMapOrSetLitExpr(issues: inout [Issue]) -> Expr? {
    // The first token must be brace bracket.
    guard let head = consume(.leftBrace) else {
      issues.append(unexpectedToken(expected: "'{'"))
      return nil
    }

    // If the next consumable token is the right delimiter, we've got an empty set literal.
    if let endToken = consume(.rightBrace, afterMany: .newline) {
      return SetLitExpr(
        elems: [],
        module: module,
        range: head.range.lowerBound ..< endToken.range.upperBound)
    }

    // If the next consumable token is a colon, we've probably got an empty map literal.
    if consume(.colon, afterMany: .newline) != nil {
      // Commit to parsing the empty map literal.
      let endToken = consume(.rightBrace)
      if endToken == nil {
        issues.append(unexpectedToken(expected: "']'"))
      }

      let rangeUpperBound = (endToken?.range ?? head.range).upperBound
      return MapLitExpr(
        elems: [],
        module: module,
        range: head.range.lowerBound ..< rangeUpperBound)
    }

    // Attempt to parse a map element.
    consumeNewlines()
    let savePoint = streamPosition
    var mapElemIssues: [Issue] = []
    let firstMapElem = parseMapElem(issues: &mapElemIssues)
    rewind(to: savePoint)

    if firstMapElem != nil {
      // Commit to parsing a map literal.
      let elems = parseList(delimitedBy: .rightBrace, issues: &issues, with: parseMapElem)

      let endToken = consume(.rightBrace)
      let rangeUpperBound: SourceLocation
      if endToken == nil {
        rangeUpperBound = elems.last?.range.upperBound ?? head.range.upperBound
        issues.append(unexpectedToken(expected: "']'"))
      } else {
        rangeUpperBound = endToken!.range.upperBound
      }

      return MapLitExpr(
        elems: elems,
        module: module,
        range: head.range.lowerBound ..< rangeUpperBound)
    } else {
      // Commit to parsing a set literal.
      let elems = parseList(delimitedBy: .rightBrace, issues: &issues, with: parseExpr)

      let endToken = consume(.rightBrace)
      let rangeUpperBound: SourceLocation
      if endToken == nil {
        rangeUpperBound = elems.last?.range.upperBound ?? head.range.upperBound
        issues.append(unexpectedToken(expected: "']'"))
      } else {
        rangeUpperBound = endToken!.range.upperBound
      }

      return SetLitExpr(
        elems: elems,
        module: module,
        range: head.range.lowerBound ..< rangeUpperBound)
    }
  }

  /// Parses a map literal element.
  func parseMapElem(issues: inout [Issue]) -> MapLitElem? {
    // Parse the key of the element.
    guard let keyToken = consume(.identifier) else {
      issues.append(unexpectedToken(expected: "identifier"))
      return nil
    }
    let key = IdentExpr(name: keyToken.value!, module: module, range: keyToken.range)

    // Parse the value of the element.
    guard let colon = consume(.colon, afterMany: .newline) else {
      issues.append(unexpectedToken(expected: "':'"))
      return nil
    }

    consumeNewlines()
    let value = parseExpr(issues: &issues)
      ?? InvalidExpr(module: module, range: colon.range)

    return MapLitElem(
      key: key,
      value: value,
      module: module,
      range: key.range.lowerBound ..< value.range.upperBound)
  }

}
