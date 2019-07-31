import AST
import Utils

extension Parser {

  /// Parses a property declaration.
  func parsePropDecl() -> Result<PropDecl?> {
    // The first token must be `let` or `var`.
    guard let startToken = consume(if: { $0.kind == .let || $0.kind == .var }) else {
      defer { consumeUpToNextStatementDelimiter() }
      return Result(value: nil, issues: [unexpectedToken(expected: "'let'")])
    }

    // Parse the name of the property.
    guard let name = consume(.identifier, afterMany: .newline) else {
      defer { consumeUpToNextStatementDelimiter() }
      return Result(value: nil, issues: [unexpectedToken(expected: "identifier")])
    }

    var issues: [Issue] = []
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
      issues.append(contentsOf: parseResult.issues)

      if let signature = parseResult.value {
        propDecl.typeAnnotation = signature
        propDecl.range = SourceRange(from: propDecl.range.start, to: signature.range.end)
      }
    }

    // Attempt to parse an initial binding expression.
    if let operatorToken = consume(afterMany: .newline, if: { $0.isBindingOperator }) {
      consumeNewlines()
      let parseResult = parseExpression()
      issues.append(contentsOf: parseResult.issues)

      if let expression = parseResult.value {
        propDecl.initialBinding = (operatorToken.asBindingOperator!, expression)
        propDecl.range = SourceRange(from: propDecl.range.start, to: expression.range.end)
      }
    } else if let assignOperator = consume(.assign, afterMany: .newline) {
      // Catch invalid uses of the "assign" token in lieu of a binding operator.
      issues.append(parseFailure(
        .unexpectedToken(expected: "binding operator", got: assignOperator),
        range: assignOperator.range))

      // Parse the expression in case it contains syntax issues as well.
      let parseResult = parseExpression()
      issues.append(contentsOf: parseResult.issues)
    }

    return Result(value: propDecl, issues: issues)
  }

  /// Parses a function declaration.
  func parseFunDecl() -> Result<FunDecl?> {
    let startToken: Token
    let name: String
    let kind: FunctionKind

    var issues: [Issue] = []

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
        issues.append(unexpectedToken(expected: "identifier"))
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
      return Result(value: nil, issues: [unexpectedToken(expected: "'fun'")])
    }

    // Attempt to parse the list of generic placeholders.
    let placeholdersParseResult = parsePlaceholderList()
    let placeholders = placeholdersParseResult.value
    issues.append(contentsOf: placeholdersParseResult.issues)

    // Parse a parameter list.
    var parameters: [ParamDecl] = []
    consumeNewlines()
    if consume(.leftParen) == nil {
      issues.append(unexpectedToken(expected: "'('"))
    } else {
      let parametersParseResult = parseList(
        delimitedBy: .rightParen,
        parsingElementWith: parseParamDecl)
      issues.append(contentsOf: parametersParseResult.issues)

      // Make sure there are no duplicate parameters.
      var existing: Set<String> = []
      for parameter in parametersParseResult.value {
        guard !existing.contains(parameter.name) else {
          issues.append(
            parseFailure(.duplicateParameter(name: parameter.name), range: parameter.range))
          continue
        }
        existing.insert(parameter.name)
      }

      parameters = parametersParseResult.value
      if consume(.rightParen) == nil {
        issues.append(unexpectedToken(expected: "')'"))
      }
    }

    // Attempt to parse a codomain.
    var codomain: Node?
    if consume(.arrow, afterMany: .newline) != nil {
      consumeNewlines()
      let backtrackPosition = streamPosition
      let codomainParseResult = parseQualSign()
      issues.append(contentsOf: codomainParseResult.issues)

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
      issues.append(contentsOf: bodyParseResult.issues)
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
      issues: issues)
  }

  /// Parses a parameter declaration.
  func parseParamDecl() -> Result<ParamDecl?> {
    // Attempt to parse the label and formal name of the parameter, the last being required.
    guard let first = consume(.underscore) ?? consume(.identifier) else {
      defer { consume() }
      return Result(value: nil, issues: [unexpectedToken(expected: "identifier")])
    }

    let second = consume(.identifier, afterMany: .newline) ?? first
    guard second.kind != .underscore else {
      return Result(value: nil, issues: [unexpectedToken(expected: "identifier")])
    }

    let label = first.kind == .underscore
      ? nil
      : first.value

    var issues: [Issue] = []
    let paramDecl = ParamDecl(
      label: label,
      name: second.value!,
      module: module,
      range: SourceRange(from: first.range.start, to: second.range.end))

    // Attempt to parse a type annotation.
    if consume(.colon, afterMany: .newline) != nil {
      consumeNewlines()
      let annotationParseResult = parseQualSign()
      issues.append(contentsOf: annotationParseResult.issues)

      if let signature = annotationParseResult.value {
        paramDecl.typeAnnotation = signature
        paramDecl.range = SourceRange(from: paramDecl.range.start, to: signature.range.end)
      }
    }

    // Attempt to Parse a default binding expression.
    if consume(.assign, afterMany: .newline) != nil {
      consumeNewlines()
      let parseResult = parseExpression()
      issues.append(contentsOf: parseResult.issues)

      if let expression = parseResult.value {
        paramDecl.defaultValue = expression
        paramDecl.range = SourceRange(from: paramDecl.range.start, to: expression.range.end)
      }
    }

    return Result(value: paramDecl, issues: issues)
  }

  /// Parses a struct declaration.
  func parseStructDecl() -> Result<StructDecl?> {
    // The first token should be `struct`.
    guard let startToken = consume(.struct) else {
      defer { consume() }
      return Result(value: nil, issues: [unexpectedToken(expected: "'struct'")])
    }

    consumeNewlines()
    let nominalTypeParseResult = parseNominalType()
    guard let nominalType = nominalTypeParseResult.value else {
      return Result(value: nil, issues: nominalTypeParseResult.issues)
    }

    return Result(
      value: StructDecl(
        name: nominalType.name,
        placeholders: nominalType.placeholders,
        body: nominalType.body,
        module: module,
        range: SourceRange(from: startToken.range.start, to: nominalType.body.range.end)),
      issues: nominalTypeParseResult.issues)
  }

  /// Parses a union nested member declaration.
  func parseUnionNestedMemberDecl() -> Result<UnionNestedMemberDecl?> {
    // The first token should be `case`.
    guard let startToken = consume(.case) else {
      defer { consume() }
      return Result(value: nil, issues: [unexpectedToken(expected: "'case'")])
    }

    let nominalType: NominalTypeDecl
    let issues: [Issue]

    consumeNewlines()
    switch peek().kind {
    case .struct:
      let typeParseResult = parseStructDecl()
      guard typeParseResult.value != nil else {
        return Result(value: nil, issues: typeParseResult.issues)
      }
      nominalType = typeParseResult.value!
      issues = typeParseResult.issues

    case .union:
      let typeParseResult = parseUnionDecl()
      guard typeParseResult.value != nil else {
        return Result(value: nil, issues: typeParseResult.issues)
      }
      nominalType = typeParseResult.value!
      issues = typeParseResult.issues

    default:
      return Result(value: nil, issues: [unexpectedToken(expected: "struct or union declaration")])
    }

    return Result(
      value: UnionNestedMemberDecl(
        nominalTypeDecl: nominalType,
        module: module,
        range: SourceRange(from: startToken.range.start, to: nominalType.range.end)),
      issues: issues)
  }

  /// Parses a union declaration.
  func parseUnionDecl() -> Result<UnionDecl?> {
    // The first token should be `union`.
    guard let startToken = consume(.union) else {
      defer { consume() }
      return Result(value: nil, issues: [unexpectedToken(expected: "'union'")])
    }

    consumeNewlines()
    let nominalTypeParseResult = parseNominalType()
    guard let nominalType = nominalTypeParseResult.value else {
      return Result(value: nil, issues: nominalTypeParseResult.issues)
    }

    return Result(
      value: UnionDecl(
        name: nominalType.name,
        placeholders: nominalType.placeholders,
        body: nominalType.body,
        module: module,
        range: SourceRange(from: startToken.range.start, to: nominalType.body.range.end)),
      issues: nominalTypeParseResult.issues)
  }

  /// Parses an interface declaration.
  func parseInterfaceDecl() -> Result<InterfaceDecl?> {
    // The first token should be `interface`.
    guard let startToken = consume(.interface) else {
      defer { consume() }
      return Result(value: nil, issues: [unexpectedToken(expected: "'interface'")])
    }

    consumeNewlines()
    let nominalTypeParseResult = parseNominalType()
    guard let nominalType = nominalTypeParseResult.value else {
      return Result(value: nil, issues: nominalTypeParseResult.issues)
    }

    return Result(
      value: InterfaceDecl(
        name: nominalType.name,
        placeholders: nominalType.placeholders,
        body: nominalType.body,
        module: module,
        range: SourceRange(from: startToken.range.start, to: nominalType.body.range.end)),
      issues: nominalTypeParseResult.issues)
  }

  /// Helper that factorizes nominal type parsing.
  func parseNominalType() -> Result<NominalType?> {
    // Parse the name of the type.
    guard let name = consume(.identifier)?.value else {
      defer { consume() }
      return Result(value: nil, issues: [unexpectedToken(expected: "identifier")])
    }

    var issues: [Issue] = []

    // Attempt to parse the list of generic placeholders.
    let placeholdersParseResult = parsePlaceholderList()
    let placeholders = placeholdersParseResult.value
    issues.append(contentsOf: placeholdersParseResult.issues)

    // Parse the body of the type.
    consumeNewlines()
    let bodyParseResult = parseStatementBlock()
    issues.append(contentsOf: bodyParseResult.issues)

    guard let body = bodyParseResult.value else {
      return Result(value: nil, issues: issues)
    }

    // Mark all regular functions as methods.
    for stmt in body.statements {
      if let methDecl = stmt as? FunDecl, methDecl.kind == .regular {
        methDecl.kind = .method
      }
    }

    return Result(
      value: NominalType(name: name, placeholders: placeholders, body: body),
      issues: issues)
  }

  /// Helper to parse list of generic placeholders.
  func parsePlaceholderList() -> Result<[String]> {
    var issues: [Issue] = []

    var placeholders: [String] = []
    if consume(.lt, afterMany: .newline) != nil {
      let namesParseResult = parseList(delimitedBy: .gt) { () -> Result<Token?> in
        guard let token = consume(.identifier) else {
          defer { consume() }
          return Result(value: nil, issues: [unexpectedToken(expected: "identifier")])
        }
        return Result(value: token, issues: [])
      }
      issues.append(contentsOf: namesParseResult.issues)

      // Parse the list's delimiter.
      if consume(.gt) == nil {
        issues.append(unexpectedToken(expected: "'>'"))
      }

      for token in namesParseResult.value {
        // Make sure there's no duplicate key.
        guard !placeholders.contains(token.value!) else {
          issues.append(parseFailure(.duplicateKey(key: token.value!), range: token.range))
          continue
        }
        placeholders.append(token.value!)
      }
    }

    return Result(value: placeholders, issues: issues)
  }

}

struct NominalType {

  let name: String
  let placeholders: [String]
  let body: Block

}
