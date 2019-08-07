import AST

extension Parser {

  /// Parses a qualified type signature.
  func parseQualSign(issues: inout [Issue]) -> QualTypeSign? {
    // If the first token is a left parenthesis, attempt first to parse a function signature, as
    // it is more likely than an enclosed signature.
    if peek().kind == .leftParen {
      let savePoint = streamPosition
      var funSignIssues: [Issue] = []
      let funSign = parseFunSign(issues: &funSignIssues)
      if funSign != nil {
        // If we succeeded to parse a function signature, we return it without qualifier.
        issues.append(contentsOf: funSignIssues)
        return QualTypeSign(quals: [], sign: funSign, module: module, range: funSign!.range)
      } else {
        // If we failed to parse a function signature, attempt to parse an enclosed signature.
        rewind(to: savePoint)
        consume(.leftParen)
        consumeNewlines()

        var enclosedSignIssues: [Issue] = []
        if let enclosed = parseQualSign(issues: &enclosedSignIssues) {
          issues.append(contentsOf: enclosedSignIssues)
          if consume(.rightParen, afterMany: .newline) == nil {
            issues.append(unexpectedToken(expected: "')'"))
          }
          return enclosed
        }
      }

      // If we couldn't parse an enclosed signature, assume the error occured while parsing a
      // function signature.
      issues.append(contentsOf: funSignIssues)
      return nil
    }

    var range = peek().range

    // Parse the qualifiers (if any).
    var qualSet: TypeQualSet = []
    while let attrToken = consume(.attribute) {
      range = range.lowerBound ..< attrToken.range.upperBound

      switch attrToken.value! {
      case "@cst": qualSet.insert(.cst)
      case "@mut": qualSet.insert(.mut)
      default:
        issues.append(
          parseFailure(Issue.invalidTypeQual(value: attrToken.value!), range: attrToken.range))
      }

      // Skip trailing new lines.
      consumeNewlines()
    }

    // Parse the unqualified type signature.
    let savePoint = streamPosition
    var signIssues: [Issue] = []
    guard let sign = parseTypeSign(issues: &signIssues) else {
      // If the signature could not be parsed, make sure at least one qualifier could.
      guard !qualSet.isEmpty else {
        issues.append(contentsOf: signIssues)
        return nil
      }

      // If there is at least one qualifier, we can ignore the signature's parsing failure, rewind
      // the token stream and return a signature without explicit unqualified signature.
      rewind(to: savePoint)
      return QualTypeSign(quals: qualSet, sign: nil, module: module, range: range)
    }

    issues.append(contentsOf: signIssues)
    range = qualSet.isEmpty
      ? sign.range
      : range.lowerBound ..< sign.range.upperBound
    return QualTypeSign(quals: qualSet, sign: sign, module: module, range: range)
  }

  /// Parses an unqualified type signature.
  func parseTypeSign(issues: inout [Issue]) -> TypeSign? {
    var sign: TypeSign

    switch peek().kind {
    case .identifier:
      guard let node = parseIdentSign(issues: &issues)
        else { return nil }
      sign = node

    case .leftParen:
      // First, attempt to parse a function signature.
      let savePoint = streamPosition
      var funSignIssues: [Issue] = []
      let funSign = parseFunSign(issues: &funSignIssues)
      if funSign != nil {
        issues.append(contentsOf: funSignIssues)
        sign = funSign!
      } else {
        // If we failed to parse a function signature, attempt to parse an enclosed signature.
        rewind(to: savePoint)
        consume(.leftParen)
        consumeNewlines()

        var enclosedSignIssues: [Issue] = []
        if let enclosed = parseTypeSign(issues: &enclosedSignIssues) {
          issues.append(contentsOf: enclosedSignIssues)
          if consume(.rightParen, afterMany: .newline) == nil {
            issues.append(unexpectedToken(expected: "')'"))
          }
          sign = enclosed
        } else {
          // If we couldn't parse an enclosed signature, assume the error occured while parsing a
          // function signature.
          issues.append(contentsOf: funSignIssues)
          return nil
        }
      }

    case .doubleColon:
      let head = consume()!
      guard let ident = parseIdentSign(issues: &issues)
        else { return nil }
      sign = ImplicitNestedIdentSign(
        ownee: ident,
        module: module,
        range: head.range.lowerBound ..< ident.range.upperBound)

    default:
      issues.append(unexpectedToken(expected: "type signature"))
      return nil
    }

    while let separator = consume(.doubleColon, afterMany: .newline) {
      // Make sure the owner is a type identifier, by construction.
      guard (sign is IdentSign) || (sign is NestedIdentSign) || (sign is ImplicitSelectExpr) else {
        issues.append(unexpectedToken(got: separator))
        break
      }
      guard let ownee = parseIdentSign(issues: &issues)
        else { break }

      sign = NestedIdentSign(
        owner: sign,
        ownee: ownee,
        module: module,
        range: sign.range.lowerBound ..< ownee.range.upperBound)
    }

    return sign
  }

  /// Parses a type identifier signature.
  func parseIdentSign(issues: inout [Issue]) -> IdentSign? {
    // The first token should be an identifier.
    guard let head = consume(.identifier) else {
      issues.append(unexpectedToken(expected: "identifier"))
      return nil
    }

    let ident = IdentSign(name: head.value!, module: module, range: head.range)

    // Attempt to parse a specialization list.
    if let (specArgs, specArgsRange) = parseSpecArgs(issues: &issues) {
      ident.specArgs = specArgs
      ident.range = ident.range.lowerBound ..< specArgsRange.upperBound
    }

    return ident
  }

  /// Parses a specialization list.
  func parseSpecArgs(issues: inout [Issue])
    -> (specArgs: [String: QualTypeSign], range: SourceRange)?
  {
    if let head = consume(.lt, afterMany: .newline) {
      // Commit to parse a specialization list.
      let specTokens = parseList(delimitedBy: .gt, issues: &issues, with: parseSpecArg)

      let range: SourceRange
      if let tail = consume(.gt) {
        range = head.range.lowerBound ..< tail.range.upperBound
      } else {
        issues.append(unexpectedToken(expected: "'>'"))
        range = head.range.lowerBound ..< (specTokens.last?.0 ?? head).range.upperBound
      }

      // Make sure there's no duplicate key.
      var keys: Set<String> = []
      for arg in specTokens {
        if keys.contains(arg.0.value!) {
          issues.append(parseFailure(
            Issue.duplicateGenericParam(key: arg.0.value!), range: arg.0.range))
        }
        keys.insert(arg.0.value!)
      }

      let specArgs = Dictionary(uniqueKeysWithValues: specTokens.map {
        (token, sign) in (token.value!, sign)
      })
      return (specArgs, range)
    }

    return nil
  }

  /// Parses a specialization argument.
  ///
  /// This parser commits if it can recognize a name followed by `=`. If it fails past this point,
  /// it attempts to recover at the next comma, closing angle bracket or statement delimiter.
  func parseSpecArg(issues: inout [Issue]) -> (Token, QualTypeSign)? {
    // Parse the name of the placeholder.
    guard let name = consume(.identifier) else {
      issues.append(unexpectedToken(expected: "identifier"))
      return nil
    }

    // Parse the signature to which it should map.
    guard let assign = consume(.assign, afterMany: .newline) else {
      issues.append(unexpectedToken(expected: "'='"))
      return nil
    }

    consumeNewlines()
    var sign = parseQualSign(issues: &issues)
    if sign == nil {
      sign = QualTypeSign(
        quals: [],
        sign: InvalidSign(module: module, range: assign.range),
        module: module,
        range: assign.range)
      recover(atNextKinds: [.comma, .gt, .newline])
    }

    return (name, sign!)
  }

  /// Parses a function type signature.
  ///
  /// This parser commits if it can recognize a parameter list followed by an arrow. If it fails
  /// past this point, it attempts to recover at the next comma, closing parenthesis or statement
  // delimiter.
  func parseFunSign(issues: inout [Issue]) -> FunSign? {
    // The first token should be left parenthesis.
    guard let head = consume(.leftParen) else {
      issues.append(unexpectedToken(expected: "'('"))
      return nil
    }

    // Parse the domain.
    let params = parseList(delimitedBy: .rightParen, issues: &issues, with: parseParamSign)
    if consume(.rightParen, afterMany: .newline) == nil {
      issues.append(unexpectedToken(expected: "')'"))
    }

    // Parse the codomain.
    guard let arrow = consume(.arrow, afterMany: .newline) else {
      // Note that we can't recover from this error, as this will prevent parsing enclosed
      // signature relying on this particular failure.
      issues.append(unexpectedToken(expected: "'->'"))
      return nil
    }

    consumeNewlines()
    var codom = parseQualSign(issues: &issues)
    if codom == nil {
      recover(atNextKinds: [.comma, .rightParen, .newline])
      codom = QualTypeSign(
        quals: [],
        sign: InvalidSign(module: module, range: arrow.range),
        module: module,
        range: arrow.range)
    }

    return FunSign(
      params: params,
      codom: codom!,
      module: module,
      range: head.range.lowerBound ..< codom!.range.upperBound)
  }

  /// Parses a function parameter signature.
  ///
  /// This parser commits if it can recognize a label followed by a colon. If it fails past this
  /// point, it attempts to recover at the next comma, closing parenthesis or arrow or statement
  /// delimiter.
  func parseParamSign(issues: inout [Issue]) -> ParamSign? {
    // Parse the label of the parameter.
    guard let head = consume([.identifier, .underscore]) else {
      issues.append(unexpectedToken(expected: "identifier"))
      return nil
    }

    // Parse the qualified signature of the parameter.
    guard let colon = consume(.colon, afterMany: .newline) else {
      issues.append(unexpectedToken(expected: "':'"))
      return nil
    }

    consumeNewlines()
    var sign = parseQualSign(issues: &issues)
    if sign == nil {
      recover(atNextKinds: [.comma, .rightParen, .newline])
      sign = QualTypeSign(
        quals: [],
        sign: InvalidSign(module: module, range: colon.range),
        module: module,
        range: colon.range)
    }

    let label: String? = head.kind == .underscore
      ? nil
      : head.value

    return ParamSign(
      label: label,
      sign: sign!,
      module: module,
      range: head.range.lowerBound ..< sign!.range.upperBound)
  }

}
