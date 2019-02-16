import AST

extension Parser {

  /// Parses a qualified type signature.
  func parseQualSign() throws -> QualTypeSign {
    // First, attempt to parse an enclosed signature.
    if peek().kind == .leftParen {
      let backtrackPosition = streamPosition
      let start = consume()!.range.start
      if let enclosed = try? parseQualSign() {
        guard let delimiter = consume(.rightParen, afterMany: .newline)
          else { throw unexpectedToken(expected: ")") }
        enclosed.range = SourceRange(from: start, to: delimiter.range.end)
        return enclosed
      } else {
        rewind(to: backtrackPosition)
      }
    }

    // Parse the qualifiers (if any).
    var qualifiers: Set<TypeQualifier> = []
    var firstQualifier: Token? = nil
    while let qualifier = consume(.qualifier) {
      if firstQualifier == nil {
        firstQualifier = qualifier
      }

      switch qualifier.value! {
      case "cst": qualifiers.insert(.cst)
      case "mut": qualifiers.insert(.mut)
      default:
        throw parseFailure(.invalidQualifier(value: qualifier.value!))
      }

      // Skip trailing new lines.
      consumeNewlines()
    }

    // Parse the signature (optionally if we could parse at least one qualifier).
    let sign: Node? = qualifiers.isEmpty
      ? try parseTypeSign()
      : attempt(parseTypeSign)

    let start = firstQualifier?.range.start ?? sign!.range.start
    let end = sign?.range.end ?? firstQualifier!.range.end
    return QualTypeSign(
      qualifiers: qualifiers,
      signature: sign,
      module: module,
      range: SourceRange(from: start, to: end))
  }

  /// Parses an unqualified type signature.
  func parseTypeSign() throws -> Node {
    switch peek().kind {
    case .identifier:
      return try parseTypeIdentifier()

    case .leftParen:
      // First, attempt to parse an enclosed signature.
      let backtrackPosition = streamPosition
      let start = consume()!.range.start
      consumeNewlines()
      if let enclosed = try? parseTypeSign() {
        guard let delimiter = consume(.rightParen, afterMany: .newline)
          else { throw unexpectedToken(expected: ")") }
        enclosed.range = SourceRange(from: start, to: delimiter.range.end)
        return enclosed
      } else {
        // If parsing an enclosed signature failed, fall back to parsing a function signature.
        rewind(to: backtrackPosition)
        return try parseFunSign()
      }

    default:
      throw unexpectedToken(expected: "type signature")
    }
  }

  /// Parses a type identifier.
  func parseTypeIdentifier() throws -> TypeIdent {
    guard let token = consume(.identifier)
      else { throw unexpectedToken(expected: "identifier") }
    let ident = TypeIdent(name: token.value!, module: module, range: token.range)

    // Attempt to parse the specialization list.
    let backtrackPosition = streamPosition
    consumeNewlines()
    if peek().kind == .lt, let keysAndValues = attempt(parseSpecializationList) {
      // Make sure there's no duplicate key.
      let duplicates = keysAndValues.duplicates { $0.0.value! }
      guard duplicates.isEmpty else {
        let key = duplicates.first!.0
        throw ParseError(.duplicateKey(key: key.value!), range: key.range)
      }
      ident.specializations = Dictionary(
        uniqueKeysWithValues: keysAndValues.map({ ($0.0.value!, $0.1) }))
    } else {
      rewind(to: backtrackPosition)
    }

    return ident
  }

  /// Parses a specialization list.
  func parseSpecializationList() throws -> [(Token, Node)] {
    guard consume(.lt) != nil
      else { throw unexpectedToken(expected: "<") }
    let keysAndValues = try parseList(delimitedBy: .gt, parsingElementWith: parseSpecArg)
    guard consume(.gt) != nil
      else { throw unexpectedToken(expected: ">") }
    return keysAndValues
  }

  /// Parses a specialization argument.
  func parseSpecArg() throws -> (Token, Node) {
    // Parse the name of the placeholder.
    guard let name = consume(.identifier)
      else { throw unexpectedToken(expected: "identifier") }

    // Parse the `=` symbol.
    guard consume(.copy, afterMany: .newline) != nil
      else { throw unexpectedToken(expected: "=") }

    // Parse the signature it should maps to.
    consumeNewlines()
    let sign = try parseTypeSign()
    return (name, sign)
  }

  /// Parses a function type signature.
  func parseFunSign() throws -> FunSign {
    // Parse the parameter list.
    guard let startToken = consume(.leftParen)
      else { throw unexpectedToken(expected: "(") }
    let parameters = try parseList(delimitedBy: .rightParen, parsingElementWith: parseParamSign)
    guard consume(.rightParen) != nil
      else { throw unexpectedToken(expected: ")") }

    // Parse the codomain.
    guard consume(.arrow, afterMany: .newline) != nil
      else { throw unexpectedToken(expected: "->") }
    consumeNewlines()
    let codomain = try parseQualSign()
    return FunSign(
      parameters: parameters,
      codomain: codomain,
      module: module,
      range: SourceRange(from: startToken.range.start, to: codomain.range.end))
  }

  /// Parses a function parameter signature.
  func parseParamSign() throws -> ParamSign {
    // Parse the label of the parameter.
    let label: Token
    switch peek().kind {
    case .identifier, .underscore:
      label = consume()!
    default:
      throw unexpectedToken(expected: "identifier")
    }

    // Parse the qualified signature of the parameter.
    guard consume(.colon, afterMany: .newline) != nil
      else { throw unexpectedToken(expected: ":") }
    consumeNewlines()
    let sign = try parseQualSign()
    return ParamSign(
      label: label.value,
      typeAnnotation: sign,
      module: module,
      range: SourceRange(from: label.range.start, to: sign.range.end))
  }

}
