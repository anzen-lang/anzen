import AST
import Utils

extension Parser {

  /// Parses a top-level declaration.
  func parseDecl() -> Result<ASTNode?> {
    switch peek().kind {
    case .attribute:
      // Qualifiers prefixing a declarations denote attributes.
      var attrs: [DeclAttr] = []
      var issues: [Issue] = []
      while peek().kind == .attribute {
        let parseResult = parseDeclAttr()
        issues.append(contentsOf: parseResult.issues)
        if let attr = parseResult.value {
          attrs.append(attr)
          consumeNewlines()
        } else {
          consume()
        }
      }

      // The next construction has to be a property or a function declaration. Nonetheless, we will
      // parse any statement or declaration anyway for the sake of error reporting.
      let parseResult = parseDecl()
      issues.append(contentsOf: parseResult.issues)

      switch parseResult.value {
      case nil:
        return Result(value: nil, issues: issues)

      case let decl as PropDecl:
        decl.attrs = Set(attrs)
        if !attrs.isEmpty {
          decl.range = attrs.first!.range.lowerBound ..< decl.range.upperBound
        }
        return Result(value: decl, issues: issues)

      case let decl as FunDecl:
        decl.attrs = Set(attrs)
        if !attrs.isEmpty {
          decl.range = attrs.first!.range.lowerBound ..< decl.range.upperBound
        }
        return Result(value: decl, issues: issues)

      case .some(let node):
        let issue = parseFailure(
          .unexpectedConstruction(expected: "property or function declaration", got: node),
          range: node.range)
        return Result(value: parseResult.value, issues: issues + [issue])
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
      let parseResult = parseDecl()
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

    default:
      return Result(value: nil, issues: [unexpectedToken(expected: "declaration")])
    }
  }

  /// Parses a property declaration.
  func parsePropDecl() -> Result<PropDecl?> {
    var issues: [Issue] = []

    // The first token must be `let` or `var`.
    guard let head = consume([.let, .var])
      else { return Result(value: nil, issues: [unexpectedToken(expected: "'let'")]) }
    var tail = head

    // Parse the property's name.
    let name: String
    if let nameToken = consume(.identifier, afterMany: .newline) {
      tail = nameToken
      name = nameToken.value!
    } else {
      name = ""
      issues.append(unexpectedToken(expected: "identifier"))
    }

    let propDecl = PropDecl(
      name: name,
      isReassignable: head.kind == .var,
      module: module,
      range: head.range.lowerBound ..< tail.range.upperBound)

    // Attempt to parse a type annotation.
    if consume(.colon, afterMany: .newline) != nil {
      consumeNewlines()
      let parseResult = parseQualSign()
      issues.append(contentsOf: parseResult.issues)

      if let sign = parseResult.value {
        propDecl.sign = sign
        propDecl.range = head.range.lowerBound ..< sign.range.upperBound
      }
    }

    // Attempt to parse an initial binding.
    let opToken = peek(afterMany: .newline)
    if (opToken!.isBindingOperator || opToken!.kind == .assign) {
      consumeNewlines()
      let parseResult = parseBinding()
      issues.append(contentsOf: parseResult.issues)
      if let initializer = parseResult.value {
        propDecl.initializer = initializer
        propDecl.range = head.range.lowerBound ..< initializer.value.range.upperBound
      }
    }

    return Result(value: propDecl, issues: issues)
  }

  /// Parses a function declaration.
  func parseFunDecl() -> Result<FunDecl?> {
    let head: Token
    let name: String
    let kind: FunDecl.Kind
    var issues: [Issue] = []

    if let funToken = consume(.fun) {
      head = funToken
      kind = .regular

      // Parse the function's name.
      if let nameToken = consume(TokenKind.Category.name, afterMany: .newline) {
        // Make sure the identifier isn't a reserved keyword.
        if nameToken.isKeyword {
          name = ""
          issues.append(unexpectedToken(expected: "identifier", got: nameToken))
        } else {
          name = nameToken.value!
        }
      } else {
        name = ""
        issues.append(unexpectedToken(expected: "identifier"))
      }
    } else if let newToken = consume(.new) {
      head = newToken
      name = "new"
      kind = .constructor
    } else if let newToken = consume(.del) {
      head = newToken
      name = "del"
      kind = .destructor
    } else {
      return Result(value: nil, issues: [unexpectedToken(expected: "'fun'")])
    }

    let funDecl = FunDecl(name: name, kind: kind, module: module, range: head.range)

    // Attempt to parse a list of generic parameter declarations.
    let genericParamsParseResult = parseGenericParamDeclList()
    funDecl.genericParams = genericParamsParseResult.value
    issues.append(contentsOf: genericParamsParseResult.issues)

    // Parse a parameter list.
    if consume(.leftParen, afterMany: .newline) == nil {
      issues.append(unexpectedToken(expected: "'('"))
    }

    let paramsParseResult = parseCommaSeparatedList(
      delimitedBy: .rightParen,
      with: parseParamDecl)
    funDecl.params = paramsParseResult.value
    issues.append(contentsOf: paramsParseResult.issues)

    // Make sure there are no duplicate parameters.
    var paramNames: Set<String> = []
    for param in paramsParseResult.value {
      if paramNames.contains(param.name) {
        issues.append(parseFailure(.duplicateParameter(name: param.name), range: param.range))
      }
      paramNames.insert(param.name)
    }

    if let paren = consume(.rightParen, afterMany: .newline) {
      funDecl.range = head.range.lowerBound ..< paren.range.upperBound
    } else {
      issues.append(unexpectedToken(expected: "')'"))
    }

    // Attempt to parse a codomain.
    if consume(.arrow, afterMany: .newline) != nil {
      consumeNewlines()
      let signParseResult = parseQualSign()
      issues.append(contentsOf: signParseResult.issues)

      if let sign = signParseResult.value {
        funDecl.codom = sign
        funDecl.range = head.range.lowerBound ..< sign.range.upperBound
      } else {
        consumeMany { !$0.isStatementDelimiter && ($0.kind != .leftBrace) && ($0.kind != .eof) }
      }
    }

    // Attemt to parse a function body.
    if peek(afterMany: .newline)?.kind == .leftBrace {
      consumeNewlines()
      let bodyParseResult = parseBraceStmt()
      issues.append(contentsOf: bodyParseResult.issues)

      if let body = bodyParseResult.value {
        funDecl.body = body
        funDecl.range = head.range.lowerBound ..< body.range.upperBound
      }
    }

    return Result(value: funDecl, issues: issues)
  }

  /// Parses a parameter declaration.
  func parseParamDecl() -> Result<ParamDecl?> {
    // Attempt to parse the label and formal name of the parameter, the last being required.
    guard let first = consume(.underscore) ?? consume(.identifier)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "identifier")]) }

    let second = consume(.identifier, afterMany: .newline) ?? first
    guard second.kind != .underscore
      else { return Result(value: nil, issues: [unexpectedToken(expected: "identifier")]) }

    let label = first.kind == .underscore
      ? nil
      : first.value

    var issues: [Issue] = []
    let paramDecl = ParamDecl(
      label: label,
      name: second.value!,
      module: module,
      range: first.range.lowerBound ..< second.range.upperBound)

    // Attempt to parse a type annotation.
    if consume(.colon, afterMany: .newline) != nil {
      consumeNewlines()
      let parseResult = parseQualSign()
      issues.append(contentsOf: parseResult.issues)

      if let sign = parseResult.value {
        paramDecl.sign = sign
        paramDecl.range = first.range.lowerBound ..< sign.range.upperBound
      }
    }

    // Attempt to Parse a default binding expression.
    if consume(.assign, afterMany: .newline) != nil {
      consumeNewlines()
      let parseResult = parseExpr()
      issues.append(contentsOf: parseResult.issues)

      if let expr = parseResult.value {
        paramDecl.defaultValue = expr
        paramDecl.range = first.range.lowerBound ..< expr.range.upperBound
      }
    }

    return Result(value: paramDecl, issues: issues)
  }

  /// Parses an interface declaration.
  func parseInterfaceDecl() -> Result<InterfaceDecl?> {
    // The first token should be `interface`.
    guard let head = consume(.interface)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "'interface'")]) }

    consumeNewlines()
    let nominalTypeParseResult = parseNominalType()
    guard let nominalType = nominalTypeParseResult.value else {
      return Result(value: nil, issues: nominalTypeParseResult.issues)
    }

    let decl = InterfaceDecl(
      name: nominalType.name,
      genericParams: nominalType.genericParams,
      body: nominalType.body,
      module: module,
      range: head.range.lowerBound ..< nominalType.body.range.upperBound)
    return Result(value: decl, issues: nominalTypeParseResult.issues)
  }

  /// Parses a struct declaration.
  func parseStructDecl() -> Result<StructDecl?> {
    // The first token should be `struct`.
    guard let head = consume(.struct)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "'struct'")]) }

    consumeNewlines()
    let nominalTypeParseResult = parseNominalType()
    guard let nominalType = nominalTypeParseResult.value else {
      return Result(value: nil, issues: nominalTypeParseResult.issues)
    }

    let decl = StructDecl(
      name: nominalType.name,
      genericParams: nominalType.genericParams,
      body: nominalType.body,
      module: module,
      range: head.range.lowerBound ..< nominalType.body.range.upperBound)
    return Result(value: decl, issues: nominalTypeParseResult.issues)
  }

  /// Parses a union declaration.
  func parseUnionDecl() -> Result<UnionDecl?> {
    // The first token should be `union`.
    guard let head = consume(.union)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "'union'")]) }

    consumeNewlines()
    let nominalTypeParseResult = parseNominalType()
    guard let nominalType = nominalTypeParseResult.value else {
      return Result(value: nil, issues: nominalTypeParseResult.issues)
    }

    let decl = UnionDecl(
      name: nominalType.name,
      genericParams: nominalType.genericParams,
      body: nominalType.body,
      module: module,
      range: head.range.lowerBound ..< nominalType.body.range.upperBound)
    return Result(value: decl, issues: nominalTypeParseResult.issues)
  }

  /// Parses a union nested member declaration.
  func parseUnionNestedMemberDecl() -> Result<UnionNestedMemberDecl?> {
    // The first token should be `case`.
    guard let head = consume(.case)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "'case'")]) }

    let nominalType: NominalTypeDecl
    let issues: [Issue]

    consumeNewlines()
    switch peek().kind {
    case .struct:
      let typeParseResult = parseStructDecl()
      guard typeParseResult.value != nil
        else { return Result(value: nil, issues: typeParseResult.issues) }
      nominalType = typeParseResult.value!
      issues = typeParseResult.issues

    case .union:
      let typeParseResult = parseUnionDecl()
      guard typeParseResult.value != nil
        else { return Result(value: nil, issues: typeParseResult.issues) }
      nominalType = typeParseResult.value!
      issues = typeParseResult.issues

    default:
      return Result(value: nil, issues: [unexpectedToken(expected: "struct or union declaration")])
    }

    let decl = UnionNestedMemberDecl(
      nominalTypeDecl: nominalType,
      module: module,
      range: head.range.lowerBound ..< nominalType.range.upperBound)
    return Result(value: decl, issues: issues)
  }

  /// Helper that factorizes nominal type parsing.
  func parseNominalType() -> Result<NominalType?> {
    let head = peek()
    var issues: [Issue] = []

    // Parse the name of the type.
    let name: String
    if let nameToken = consume(.identifier) {
      name = nameToken.value!
    } else {
      name = ""
      issues.append(unexpectedToken(expected: "identifier"))
      recover(atNextKinds: [.leftBrace])
    }

    // Attempt to parse a list of generic parameter declarations.
    let genericParamsParseResult = parseGenericParamDeclList()
    issues.append(contentsOf: genericParamsParseResult.issues)

    // Parse the body of the type.
    consumeNewlines()
    let bodyParseResult = parseBraceStmt()
    issues.append(contentsOf: bodyParseResult.issues)

    let body = bodyParseResult.value
      ?? BraceStmt(stmts: [], module: module, range: head.range)

    // Mark all regular functions as methods.
    for stmt in body.stmts {
      if let methDecl = stmt as? FunDecl, methDecl.kind == .regular {
        methDecl.kind = .method
      }
    }

    let tyDecl = NominalType(
      name: name,
      genericParams: genericParamsParseResult.value,
      body: body)
    return Result(value: tyDecl, issues: issues)
  }

  /// Parses a list of generic parameter declarations.
  ///
  /// - Note:
  ///   This parser does not consume any token if the next consumable one isn't an opening angle
  ///   bracket (i.e. a generic paramter list's left delimiter).
  func parseGenericParamDeclList() -> Result<[GenericParamDecl]> {
    var params: [GenericParamDecl] = []
    var issues: [Issue] = []

    if consume(.lt, afterMany: .newline) != nil {
      // Commit to parse a parameter list.
      let paramsParseResult = parseCommaSeparatedList(
        delimitedBy: .gt,
        with: parseGenericParamDecl)
      issues.append(contentsOf: paramsParseResult.issues)

      params = paramsParseResult.value
      if consume(.gt) == nil {
        issues.append(unexpectedToken(expected: "'>'"))
      }

      // Make sure there's no duplicate key.
      var keys: Set<String> = []
      for param in params {
        if keys.contains(param.name) {
          issues.append(parseFailure(.duplicateKey(key: param.name), range: param.range))
        }
        keys.insert(param.name)
      }
    }

    return Result(value: params, issues: issues)
  }

  /// Parses a generic parameter declarations.
  func parseGenericParamDecl() -> Result<GenericParamDecl?> {
    if let head = consume(.identifier) {
      let decl = GenericParamDecl(name: head.value!, module: module, range: head.range)
      return Result(value: decl, issues: [])
    } else {
      return Result(value: nil, issues: [unexpectedToken(expected: "identifier")])
    }
  }

  /// Parses a declaration attribute.
  func parseDeclAttr() -> Result<DeclAttr?> {
    // The first token should be an attribute name (i.e. `'@' <name>`).
    guard let head = consume(.attribute)
      else { return Result(value: nil, issues: [unexpectedToken(expected: "attribute")]) }

    // Attempt to parse an argument list on the same line.
    var args: [Token] = []
    var issues: [Issue] = []
    var rangeUpperBound = head.range.upperBound

    if consume(.leftParen) != nil {
      // Commit to parse an argument list.
      let parseResult = parseCommaSeparatedList(delimitedBy: .rightParen, with: parseDeclAttrArg)

      args = parseResult.value
      if let delimiter = consume(.rightParen) {
        rangeUpperBound = delimiter.range.upperBound
      } else {
        rangeUpperBound = args.last?.range.upperBound ?? rangeUpperBound
        issues.append(unexpectedToken(expected: "')'"))
      }
    }

    let attr = DeclAttr(
      name: head.value!,
      args: args.map { $0.value! },
      module: module,
      range: head.range.lowerBound ..< rangeUpperBound)
    return Result(value: attr, issues: issues)
  }

  /// Parses a declaration attribute's argument.
  func parseDeclAttrArg() -> Result<Token?> {
    if let arg = consume(.identifier) {
      return Result(value: arg, issues: [])
    } else {
      return Result(value: nil, issues: [unexpectedToken(expected: "identifier")])
    }
  }

}

struct NominalType {

  let name: String
  let genericParams: [GenericParamDecl]
  let body: BraceStmt

}
