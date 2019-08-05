import AST

extension Parser {

  /// Parses a qualified type signature.
  func parseQualSign() -> Result<QualTypeSign?> {
    // If the first token is a left parenthesis, attempt first to parse a function signature, as
    // it is more likely than an enclosed signature.
    if peek().kind == .leftParen {
      let savePoint = streamPosition
      let funSignParseResult = parseFunSign()

      // If we failed to parse a function signature, attempt to parse an enclosed signature.
      guard let funSign = funSignParseResult.value else {
        rewind(to: savePoint)
        consume(.leftParen)

        consumeNewlines()
        let enclosedParseResult = parseQualSign()
        if let enclosed = enclosedParseResult.value {
          // Commit to this path if an enclosed signature could be parsed.
          var issues = enclosedParseResult.issues
          if consume(.rightParen, afterMany: .newline) == nil {
            issues.append(unexpectedToken(expected: "')'"))
          }
          return Result(value: enclosed, issues: issues)
        } else {
          // If we couldn't parse an enclosed signature, assume the error occured while parsing a
          // function signature.
          return Result(value: nil, issues: funSignParseResult.issues)
        }
      }

      // If we succeeded to parse a function signature, we return it without qualifier.
      let qualSign = QualTypeSign(quals: [], sign: funSign, module: module, range: funSign.range)
      return Result(value: qualSign, issues: funSignParseResult.issues)
    }

    var issues: [Issue] = []
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
          parseFailure(.invalidQualifier(value: attrToken.value!), range: attrToken.range))
      }

      // Skip trailing new lines.
      consumeNewlines()
    }

    // Parse the unqualified type signature.
    let savePoint = streamPosition
    let signParseResult = parseTypeSign()

    guard let sign = signParseResult.value else {
      // If the signature could not be parsed, make sure at least one qualifier could.
      guard !qualSet.isEmpty
        else { return Result(value: nil, issues: issues + signParseResult.issues) }

      // If there is at least one qualifier, we can ignore the signature's parsing failure, rewind
      // the token stream and return a signature without explicit unqualified signature.
      rewind(to: savePoint)
      let qualSign = QualTypeSign(quals: qualSet, sign: nil, module: module, range: range)
      return Result(value: qualSign, issues: issues)
    }

    issues.append(contentsOf: signParseResult.issues)
    range = qualSet.isEmpty
      ? sign.range
      : range.lowerBound ..< sign.range.upperBound

    let qualSign = QualTypeSign(
      quals: qualSet,
      sign: sign,
      module: module,
      range: range)
    return Result(value: qualSign, issues: issues)
  }

  /// Parses an unqualified type signature.
  func parseTypeSign() -> Result<TypeSign?> {
    var sign: TypeSign
    var issues: [Issue] = []

    switch peek().kind {
    case .identifier:
      let parseResult = parseIdentSign()
      issues = parseResult.issues
      guard let identSign = parseResult.value
        else { return Result(value: nil, issues: issues) }
      sign = identSign

    case .leftParen:
      // First, attempt to parse a function signature.
      let savePoint = streamPosition
      let funSignParseResult = parseFunSign()

      if let funSign = funSignParseResult.value {
        // Parsing a function signature succeeded.
        sign = funSign
      } else {
        // If we failed to parse a function signature, attempt to parse an enclosed signature.
        rewind(to: savePoint)
        consume(.leftParen)

        consumeNewlines()
        let enclosedParseResult = parseTypeSign()
        if let enclosed = enclosedParseResult.value {
          // Commit to this path if an enclosed signature could be parsed.
          issues.append(contentsOf: enclosedParseResult.issues)
          if consume(.rightParen, afterMany: .newline) == nil {
            issues.append(unexpectedToken(expected: "')'"))
          }
          sign = enclosed
        } else {
          // If we couldn't parse an enclosed signature, assume the error occured while parsing a
          // function signature.
          return Result(value: nil, issues: funSignParseResult.issues)
        }
      }

    case .doubleColon:
      let head = consume()!
      let parseResult = parseIdentSign()
      issues = parseResult.issues
      guard let ident = parseResult.value
        else { return Result(value: nil, issues: issues) }
      sign = ImplicitNestedIdentSign(
        ownee: ident,
        module: module,
        range: head.range.lowerBound ..< ident.range.upperBound)

    default:
      return Result(value: nil, issues: [unexpectedToken(expected: "type signature")])
    }

    while consume(.doubleColon, afterMany: .newline) != nil {
      let owneeParseResult = parseIdentSign()
      issues.append(contentsOf: owneeParseResult.issues)
      guard let ownee = owneeParseResult.value
        else { break }
      sign = NestedIdentSign(
        owner: sign,
        ownee: ownee,
        module: module,
        range: sign.range.lowerBound ..< ownee.range.upperBound)
    }

    return Result(value: sign, issues: issues)
  }

  /// Parses a type identifier signature.
  func parseIdentSign() -> Result<IdentSign?> {
    // The first token should be an identifier.
    guard let head = consume(.identifier) else {
      defer { consume() }
      return Result(value: nil, issues: [unexpectedToken(expected: "identifier")])
    }

    // Attempt to parse a specialization list.
    let specArgsParseResult = parseSpecArgs()
    let specArgs = specArgsParseResult?.value.list ?? [:]
    let issues = specArgsParseResult?.issues ?? []

    let range = specArgsParseResult != nil
      ? head.range.lowerBound ..< specArgsParseResult!.value.range.upperBound
      : head.range
    let identSign = IdentSign(name: head.value!, specArgs: specArgs, module: module, range: range)
    return Result(value: identSign, issues: issues)
  }

  /// Parses a specialization list.
  func parseSpecArgs() -> Result<(list: [String: QualTypeSign], range: SourceRange)>? {
    var specArgs: [(Token, QualTypeSign)] = []
    var issues: [Issue] = []

    if let head = consume(.lt, afterMany: .newline) {
      // Commit to parse a specialization list.
      let specArgsParseResult = parseCommaSeparatedList(
        delimitedBy: .gt,
        with: parseSpecArg)
      issues.append(contentsOf: specArgsParseResult.issues)
      specArgs = specArgsParseResult.value

      let rangeUpperBound: SourceLocation
      if let tail = consume(.gt) {
        rangeUpperBound = tail.range.upperBound
      } else {
        issues.append(unexpectedToken(expected: "'>'"))
        rangeUpperBound = (specArgs.last?.0 ?? head).range.upperBound
      }

      // Make sure there's no duplicate key.
      var keys: Set<String> = []
      for arg in specArgs {
        if keys.contains(arg.0.value!) {
          issues.append(parseFailure(
            .duplicateGenericParameter(key: arg.0.value!), range: arg.0.range))
        }
        keys.insert(arg.0.value!)
      }

      let returnValue = (
        list: Dictionary(uniqueKeysWithValues: specArgs.map({ arg in (arg.0.value!, arg.1) })),
        range: head.range.lowerBound ..< rangeUpperBound)
      return Result(value: returnValue, issues: issues)
    }

    return nil
  }

  /// Parses a specialization argument.
  ///
  /// This parser commits if it can recognize a name followed by `=`. If it fails past this point,
  /// it attempts to recover at the next comma, closing angle bracket or statement delimiter.
  func parseSpecArg() -> Result<(Token, QualTypeSign)?> {
    // Parse the name of the placeholder.
    guard let name = consume(.identifier)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "identifier")]) }

    // Parse the signature to which it should map.
    guard let assign = consume(.assign, afterMany: .newline)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "'='")]) }

    consumeNewlines()
    let signParseResult = parseQualSign()
    let sign: QualTypeSign
    if signParseResult.value != nil {
      sign = signParseResult.value!
    } else {
      // Look for a recovery point.
      let recoveryKinds: Set<TokenKind> = [.comma, .gt, .newline, .semicolon, .eof]
      consumeMany { !recoveryKinds.contains($0.kind) }
      sign = QualTypeSign(
        quals: [],
        sign: InvalidSign(module: module, range: assign.range),
        module: module,
        range: assign.range)
    }

    return Result(value: (name, sign), issues: signParseResult.issues)
  }

  /// Parses a function type signature.
  ///
  /// This parser commits if it can recognize a parameter list followed by an arrow. If it fails
  /// past this point, it attempts to recover at the next comma, closing parenthesis or statement
  // delimiter.
  func parseFunSign() -> Result<FunSign?> {
    // The first token should be left parenthesis.
    guard let head = consume(.leftParen)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "'('")]) }

    // Parse the domain.
    let domParseResult = parseCommaSeparatedList(
      delimitedBy: .rightParen,
      with: parseParamSign)
    var issues = domParseResult.issues

    if consume(.rightParen, afterMany: .newline) == nil {
      issues.append(unexpectedToken(expected: "')'"))
    }

    // Parse the codomain.
    guard let arrow = consume(.arrow, afterMany: .newline)
      else { return Result(value: nil, issues: issues + [unexpectedToken(expected: "'->'")]) }

    consumeNewlines()
    let codomParseResult = parseQualSign()
    issues.append(contentsOf: codomParseResult.issues)
    let codom: QualTypeSign
    if codomParseResult.value != nil {
      codom = codomParseResult.value!
    } else {
      // Look for a recovery point.
      let recoveryKinds: Set<TokenKind> = [.comma, .rightParen, .newline, .semicolon, .eof]
      consumeMany { !recoveryKinds.contains($0.kind) }
      codom = QualTypeSign(
        quals: [],
        sign: InvalidSign(module: module, range: arrow.range),
        module: module,
        range: arrow.range)
    }

    let funSign = FunSign(
      dom: domParseResult.value,
      codom: codom,
      module: module,
      range: head.range.lowerBound ..< codom.range.upperBound)
    return Result(value: funSign, issues: issues)
  }

  /// Parses a function parameter signature.
  ///
  /// This parser commits if it can recognize a label followed by a colon. If it fails past this
  /// point, it attempts to recover at the next comma, closing parenthesis or arrow or statement
  /// delimiter.
  func parseParamSign() -> Result<ParamSign?> {
    // Parse the label of the parameter.
    guard let head = consume([.identifier, .underscore])
      else { return Result(value: nil, issues: [unexpectedToken(expected: "identifier")]) }

    // Parse the qualified signature of the parameter.
    guard let colon = consume(.colon, afterMany: .newline)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "':'")]) }

    consumeNewlines()
    let signParseResult = parseQualSign()
    let sign: QualTypeSign
    if signParseResult.value != nil {
      sign = signParseResult.value!
    } else {
      // Look for a recovery point.
      let recoveryKinds: Set<TokenKind> = [.comma, .rightParen, .arrow, .newline, .semicolon, .eof]
      consumeMany { !recoveryKinds.contains($0.kind) }
      sign = QualTypeSign(
        quals: [],
        sign: InvalidSign(module: module, range: colon.range),
        module: module,
        range: colon.range)
    }

    let label: String? = head.kind == .underscore
      ? nil
      : head.value

    let paramSign = ParamSign(
      label: label,
      sign: sign,
      module: module,
      range: head.range.lowerBound ..< sign.range.upperBound)
    return Result(value: paramSign, issues: signParseResult.issues)
  }

}
