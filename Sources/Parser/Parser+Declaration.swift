import AST
import Utils

extension Parser {

  /// Parses a property declaration.
  func parsePropDecl() -> Result<PropDecl?> {
    // The first token must be `let` or `var`.
    guard let startToken = consume(if: { $0.kind == .let || $0.kind == .var }) else {
      defer { consumeUpToNextStatementDelimiter() }
      return Result(value: nil, errors: [unexpectedToken(expected: "let")])
    }

    // Parse the name of the property.
    guard let name = consume(.identifier, afterMany: .newline) else {
      defer { consumeUpToNextStatementDelimiter() }
      return Result(value: nil, errors: [parseFailure(.expectedIdentifier)])
    }

    var errors: [ParseError] = []
    let propDecl = PropDecl(
      name: name.value!,
      attributes: startToken.kind == .var
        ? [.reassignable]
        : [],
      module: module,
      range: SourceRange(from: startToken.range.start, to: name.range.end))

    // Attempt to parse a type annotation.
    if consume(.colon, afterMany: .newline) != nil {
      consumeNewlines()
      let parseResult = parseQualSign()
      errors.append(contentsOf: parseResult.errors)

      if let signature = parseResult.value {
        propDecl.typeAnnotation = signature
        propDecl.range = SourceRange(from: propDecl.range.start, to: signature.range.end)
      }
    }

    // Attempt to parse an initial binding expression.
    if let operatorToken = consume(afterMany: .newline, if: { $0.isBindingOperator }) {
      consumeNewlines()
      let parseResult = parseExpression()
      errors.append(contentsOf: parseResult.errors)

      if let expression = parseResult.value {
        propDecl.initialBinding = (operatorToken.asBindingOperator!, expression)
        propDecl.range = SourceRange(from: propDecl.range.start, to: expression.range.end)
      }
    }

    return Result(value: propDecl, errors: errors)
  }

  /// Parses a function declaration.
  func parseFunDecl() -> Result<FunDecl?> {
    let startToken: Token
    let name: String
    let kind: FunctionKind

    var errors: [ParseError] = []

    if let funToken = consume(.fun) {
      startToken = funToken
      kind = .regular

      // Parse the name of the function.
      consumeNewlines()
      if let id = consume(.identifier) {
        name = id.value!
      } else if let op = consume(if: { $0.isPrefixOperator || $0.isInfixOperator }) {
        name = op.kind.rawValue
      } else {
        name = ""
        errors.append(parseFailure(.expectedIdentifier))
      }
    } else if let newToken = consume(.new) {
      startToken = newToken
      name = "new"
      kind = .constructor
    } else if let newToken = consume(.del) {
      startToken = newToken
      name = "del"
      kind = .destructor
    } else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "fun")])
    }

    // Attempt to parse the list of generic placeholders.
    let placeholdersParseResult = parsePlaceholderList()
    let placeholders = placeholdersParseResult.value
    errors.append(contentsOf: placeholdersParseResult.errors)

    // Parse a parameter list.
    var parameters: [ParamDecl] = []
    consumeNewlines()
    if consume(.leftParen) == nil {
      errors.append(unexpectedToken(expected: "("))
    } else {
      let parametersParseResult = parseList(
        delimitedBy: .rightParen,
        parsingElementWith: parseParamDecl)
      errors.append(contentsOf: parametersParseResult.errors)

      // Make sure there are no duplicate parameters.
      var existing: Set<String> = []
      for parameter in parametersParseResult.value {
        guard !existing.contains(parameter.name) else {
          errors.append(
            ParseError(.duplicateParameter(name: parameter.name), range: parameter.range))
          continue
        }
        existing.insert(parameter.name)
      }

      parameters = parametersParseResult.value
      if consume(.rightParen) == nil {
        errors.append(unexpectedToken(expected: ")"))
      }
    }

    // Attempt to parse a codomain.
    var codomain: Node? = nil
    if consume(.arrow, afterMany: .newline) != nil {
      consumeNewlines()
      let backtrackPosition = streamPosition
      let codomainParseResult = parseQualSign()
      errors.append(contentsOf: codomainParseResult.errors)

      if let signature = codomainParseResult.value {
        codomain = signature
      } else {
        rewind(to: backtrackPosition)
        consumeMany(while: { !$0.isStatementDelimiter && ($0.kind != .leftBrace) })
      }
    }

    // Attempt to the body of the lambda.
    var body: Block?
    if let bodyParseResult = attempt(parseStatementBlock) {
      body = bodyParseResult.value
      errors.append(contentsOf: bodyParseResult.errors)
    }

    let end = body?.range.end ?? codomain?.range.end ?? startToken.range.end
    return Result(
      value: FunDecl(
        name: name,
        kind: kind,
        placeholders: placeholders,
        parameters: parameters,
        codomain: codomain,
        body: body,
        module: module,
        range: SourceRange(from: startToken.range.start, to: end)),
      errors: errors)
  }

  /// Parses a parameter declaration.
  func parseParamDecl() -> Result<ParamDecl?> {
    // Attempt to parse the label and formal name of the parameter, the last being required.
    guard let first = consume(.underscore) ?? consume(.identifier) else {
      consume()
      return Result(value: nil, errors: [unexpectedToken(expected: "identifier")])
    }

    let second = consume(.identifier, afterMany: .newline) ?? first
    guard second.kind != .underscore else {
      return Result(value: nil, errors: [parseFailure(.expectedIdentifier)])
    }

    let label = first.kind == .underscore
      ? nil
      : first.value

    var errors: [ParseError] = []
    let paramDecl = ParamDecl(
      label: label,
      name: second.value!,
      module: module,
      range: SourceRange(from: first.range.start, to: second.range.end))

    // Attempt to parse a type annotation.
    if consume(.colon, afterMany: .newline) != nil {
      consumeNewlines()
      let annotationParseResult = parseQualSign()
      errors.append(contentsOf: annotationParseResult.errors)

      if let signature = annotationParseResult.value {
        paramDecl.typeAnnotation = signature
        paramDecl.range = SourceRange(from: paramDecl.range.start, to: signature.range.end)
      }
    }

    // Attempt to Parse a default binding expression.
    if consume(.assign, afterMany: .newline) != nil {
      consumeNewlines()
      let parseResult = parseExpression()
      errors.append(contentsOf: parseResult.errors)

      if let expression = parseResult.value {
        paramDecl.defaultValue = expression
        paramDecl.range = SourceRange(from: paramDecl.range.start, to: expression.range.end)
      }
    }

    return Result(value: paramDecl, errors: errors)
  }

  /// Parses a struct declaration.
  func parseStructDecl() -> Result<StructDecl?> {
    // The first token should be `struct`.
    guard let startToken = consume(.struct) else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "struct")])
    }

    consumeNewlines()
    let nominalTypeParseResult = parseNominalType()
    guard let nominalType = nominalTypeParseResult.value else {
      return Result(value: nil, errors: nominalTypeParseResult.errors)
    }

    return Result(
      value: StructDecl(
        name: nominalType.name,
        placeholders: nominalType.placeholders,
        body: nominalType.body,
        module: module,
        range: SourceRange(from: startToken.range.start, to: nominalType.body.range.end)),
      errors: nominalTypeParseResult.errors)
  }

  /// Parses an interface declaration.
  func parseInterfaceDecl() -> Result<InterfaceDecl?> {
    // The first token should be `interface`.
    guard let startToken = consume(.interface) else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "interface")])
    }

    consumeNewlines()
    let nominalTypeParseResult = parseNominalType()
    guard let nominalType = nominalTypeParseResult.value else {
      return Result(value: nil, errors: nominalTypeParseResult.errors)
    }

    return Result(
      value: InterfaceDecl(
        name: nominalType.name,
        placeholders: nominalType.placeholders,
        body: nominalType.body,
        module: module,
        range: SourceRange(from: startToken.range.start, to: nominalType.body.range.end)),
      errors: nominalTypeParseResult.errors)
  }

  /// Helper that factorizes nominal type parsing.
  func parseNominalType() -> Result<NominalType?> {
    // Parse the name of the type.
    guard let name = consume(.identifier)?.value else {
      defer { consume() }
      return Result(value: nil, errors: [unexpectedToken(expected: "identifier")])
    }

    var errors: [ParseError] = []

    // Attempt to parse the list of generic placeholders.
    let placeholdersParseResult = parsePlaceholderList()
    let placeholders = placeholdersParseResult.value
    errors.append(contentsOf: placeholdersParseResult.errors)

    // Parse the body of the type.
    consumeNewlines()
    let bodyParseResult = parseStatementBlock()
    errors.append(contentsOf: bodyParseResult.errors)

    guard let body = bodyParseResult.value else {
      return Result(value: nil, errors: errors)
    }

    // Mark all regular functions as methods.
    for stmt in body.statements {
      if let methDecl = stmt as? FunDecl, methDecl.kind == .regular {
        methDecl.kind = .method
      }
    }

    return Result(
      value: NominalType(name: name, placeholders: placeholders, body: body),
      errors: errors)
  }

  /// Helper to parse list of generic placeholders.
  func parsePlaceholderList() -> Result<[String]> {
    var errors: [ParseError] = []

    var placeholders: [String] = []
    if consume(.lt, afterMany: .newline) != nil {
      let namesParseResult = parseList(delimitedBy: .gt) { () -> Result<Token?> in
        guard let token = consume(.identifier) else {
          return Result(value: nil, errors: [parseFailure(.expectedIdentifier)])
        }
        return Result(value: token, errors: [])
      }
      errors.append(contentsOf: namesParseResult.errors)

      // Parse the list's delimiter.
      if consume(.gt) == nil {
        errors.append(unexpectedToken(expected: ">"))
      }

      for token in namesParseResult.value {
        // Make sure there's no duplicate key.
        guard !placeholders.contains(token.value!) else {
          errors.append(ParseError(.duplicateKey(key: token.value!), range: token.range))
          continue
        }
        placeholders.append(token.value!)
      }
    }

    return Result(value: placeholders, errors: errors)
  }

}

struct NominalType {

  let name: String
  let placeholders: [String]
  let body: Block

}
