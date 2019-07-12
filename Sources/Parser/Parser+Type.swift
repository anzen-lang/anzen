import AST

extension Parser {

  /// Parses a qualified type signature.
  func parseQualSign() -> Result<QualTypeSign?> {
    // If the first token is a left parenthesis, attempt first to parse a function signature, as
    // it is more likely than an enclosed signature.
    if peek().kind == .leftParen {
      let backtrackPosition = streamPosition
      let functionSignatureParseResult = parseFunSign()

      // If we failed to parse a function signature, attempt to parse an enclosed signature.
      guard let signature = functionSignatureParseResult.value else {
        rewind(to: backtrackPosition)
        let start = consume()!.range.start

        let enclosedParseResult = parseQualSign()
        if let enclosed = enclosedParseResult.value {
          // Commit to this path if an enclosed signature could be parsed.
          guard let delimiter = consume(.rightParen, afterMany: .newline) else {
            defer { consumeUpToNextStatementDelimiter() }
            return Result(
              value: nil,
              errors: enclosedParseResult.errors + [unexpectedToken(expected: ")")])
          }

          enclosed.range = SourceRange(from: start, to: delimiter.range.end)
          return Result(value: enclosed, errors: enclosedParseResult.errors)
        } else {
          // If we couldn't parse an enclosed signature, assume the error occured while parsing a
          // function signature.
          consumeUpToNextStatementDelimiter()
          return Result(value: nil, errors: functionSignatureParseResult.errors)
        }
      }

      // If we succeeded to parse a function signature, we return it without qualifier.
      return Result(
        value: QualTypeSign(
        qualifiers: [],
        signature: signature,
        module: module,
        range: signature.range),
      errors: functionSignatureParseResult.errors)
    }

    var errors: [ParseError] = []

    // Parse the qualifiers (if any).
    var qualifiers: [(value: TypeQualifier, range: SourceRange)] = []
    while let qualifier = consume(.qualifier) {
      switch qualifier.value! {
      case "cst": qualifiers.append((.cst, qualifier.range))
      case "mut": qualifiers.append((.mut, qualifier.range))
      default:
        errors.append(parseFailure(.invalidQualifier(value: qualifier.value!)))
      }

      // Skip trailing new lines.
      consumeNewlines()
    }

    // Parse the unqualified type signature.
    let backtrackPosition = streamPosition
    let signatureParseResult = parseTypeSign()

    guard let signature = signatureParseResult.value else {
      // If the signature could not be parsed, make sure at least one qualifier could.
      guard !qualifiers.isEmpty else {
        return Result(value: nil, errors: errors + signatureParseResult.errors)
      }

      // If there is at least one qualifier, we can ignore the signature's parsing failure, rewind
      // the token stream and return a signature without explicit unqualified signature.
      rewind(to: backtrackPosition)
      return Result(
        value: QualTypeSign(
          qualifiers: Set(qualifiers.map({ $0.value })),
          signature: nil, module: module,
          range: SourceRange(from: qualifiers.first!.range.start, to: qualifiers.last!.range.end)),
        errors: errors)
    }

    errors.append(contentsOf: signatureParseResult.errors)

    let range = qualifiers.isEmpty
      ? signature.range
      : SourceRange(from: qualifiers.first!.range.start, to: signature.range.end)

    return Result(
      value: QualTypeSign(
        qualifiers: Set(qualifiers.map({ $0.value })),
        signature: signature,
        module: module,
        range: range),
      errors: errors)
  }

  /// Parses an unqualified type signature.
  func parseTypeSign() -> Result<TypeSign?> {
    switch peek().kind {
    case .identifier:
      let parseResult = parseTypeIdentifier()
      return Result(value: parseResult.value, errors: parseResult.errors)

    case .leftParen:
      // First, attempt to parse a function signature.
      let backtrackPosition = streamPosition
      let functionSignatureParseResult = parseFunSign()

      // If we failed to parse a function signature, attempt to parse an enclosed signature.
      guard let signature = functionSignatureParseResult.value else {
        rewind(to: backtrackPosition)
        let start = consume()!.range.start

        let enclosedParseResult = parseTypeSign()
        if let enclosed = enclosedParseResult.value {
          // Commit to this path if an enclosed signature could be parsed.
          guard let delimiter = consume(.rightParen, afterMany: .newline) else {
            defer { consumeUpToNextStatementDelimiter() }
            return Result(
              value: nil,
              errors: enclosedParseResult.errors + [unexpectedToken(expected: ")")])
          }

          enclosed.range = SourceRange(from: start, to: delimiter.range.end)
          return Result(value: enclosed, errors: enclosedParseResult.errors)
        } else {
          // If we couldn't parse an enclosed signature, assume the error occured while parsing a
          // function signature.
          consumeUpToNextStatementDelimiter()
          return Result(value: nil, errors: functionSignatureParseResult.errors)
        }
      }

      return Result(value: signature, errors: functionSignatureParseResult.errors)

    default:
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "type signature")])
    }
  }

  /// Parses a type identifier.
  func parseTypeIdentifier() -> Result<TypeIdent?> {
    // The first token should be an identifier.
    guard let token = consume(.identifier) else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "identifier")])
    }

    let identifier = TypeIdent(name: token.value!, module: module, range: token.range)
    var errors: [ParseError] = []

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

  /// Parses a specialization list.
  func parseSpecializationList() -> Result<[(Token, QualTypeSign)]?> {
    // The first token should be a left angle bracket.
    guard consume(.lt) != nil else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "unary operator")])
    }

    var errors: [ParseError] = []

    // Parse the specialization arguments.
    let argumentsParseResult = parseList(delimitedBy: .gt, parsingElementWith: parseSpecArg)
    errors.append(contentsOf: argumentsParseResult.errors)

    guard consume(.gt) != nil else {
      defer { consumeUpToNextStatementDelimiter() }
      return Result(value: nil, errors: errors + [unexpectedToken(expected: ">")])
    }

    return Result(value: argumentsParseResult.value, errors: errors)
  }

  /// Parses a specialization argument.
  func parseSpecArg() -> Result<(Token, QualTypeSign)?> {
    // Parse the name of the placeholder.
    guard let name = consume(.identifier) else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "identifier")])
    }

    var errors: [ParseError] = []

    // Parse the signature to which it should map.
    guard consume(.assign, afterMany: .newline) != nil else {
      defer { consumeUpToNextStatementDelimiter() }
      return Result(value: nil, errors: [unexpectedToken(expected: "=")])
    }

    consumeNewlines()
    let signatureParseResult = parseQualSign()
    errors.append(contentsOf: signatureParseResult.errors)
    guard let signature = signatureParseResult.value else {
      return Result(value: nil, errors: errors)
    }

    return Result(value: (name, signature), errors: errors)
  }

  /// Parses a function type signature.
  func parseFunSign() -> Result<FunSign?> {
    // The first token should be left parenthesis.
    guard let startToken = consume(.leftParen) else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "(")])
    }

    var errors: [ParseError] = []

    // Parse the parameter list.
    let parametersParseResult = parseList(
      delimitedBy: .rightParen,
      parsingElementWith: parseParamSign)
    errors.append(contentsOf: parametersParseResult.errors)

    guard consume(.rightParen) != nil else {
      defer { consumeUpToNextStatementDelimiter() }
      return Result(value: nil, errors: errors + [unexpectedToken(expected: ")")])
    }

    // Parse the codomain.
    guard consume(.arrow, afterMany: .newline) != nil else {
      defer { consumeUpToNextStatementDelimiter() }
      return Result(value: nil, errors: errors + [unexpectedToken(expected: "->")])
    }

    consumeNewlines()
    let codomainParseResult = parseQualSign()
    errors.append(contentsOf: codomainParseResult.errors)
    guard let codomain = codomainParseResult.value else {
      return Result(value: nil, errors: errors)
    }

    return Result(
      value: FunSign(
        parameters: parametersParseResult.value,
        codomain: codomain,
        module: module,
        range: SourceRange(from: startToken.range.start, to: codomain.range.end)),
      errors: errors)
  }

  /// Parses a function parameter signature.
  func parseParamSign() -> Result<ParamSign?> {
    // Parse the label of the parameter.
    guard let label = consume([.identifier, .underscore]) else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "identifier")])
    }

    var errors: [ParseError] = []

    // Parse the qualified signature of the parameter.
    guard consume(.colon, afterMany: .newline) != nil else {
      defer { consumeUpToNextStatementDelimiter() }
      return Result(value: nil, errors: [unexpectedToken(expected: ":")])
    }

    consumeNewlines()
    let signatureParseResult = parseQualSign()
    errors.append(contentsOf: signatureParseResult.errors)
    guard let signature = signatureParseResult.value else {
      return Result(value: nil, errors: errors)
    }

    return Result(
      value: ParamSign(
        label: label.value,
        typeAnnotation: signature,
        module: module,
        range: SourceRange(from: label.range.start, to: signature.range.end)),
      errors: errors)
  }

}
