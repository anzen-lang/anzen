import AST
import Utils

extension Parser {

  /// Parses a top-level declaration.
  func parseDecl(issues: inout [Issue]) -> ASTNode? {
    switch peek().kind {
    case .attribute:
      // Qualifiers prefixing a declarations denote attributes.
      var attrs: [DeclAttr] = []
      while peek().kind == .attribute {
        if let attr = parseDeclAttr(issues: &issues) {
          attrs.append(attr)
          consumeNewlines()
        } else {
          consume()
        }
      }

      // The next construction has to be a property or a function declaration. Nonetheless, we will
      // parse any statement or declaration anyway for the sake of error reporting.
      switch parseDecl(issues: &issues) {
      case let decl as PropDecl:
        decl.attrs = Set(attrs)
        if !attrs.isEmpty {
          decl.range = attrs.first!.range.lowerBound ..< decl.range.upperBound
        }
        return decl

      case let decl as FunDecl:
        decl.attrs = Set(attrs)
        if !attrs.isEmpty {
          decl.range = attrs.first!.range.lowerBound ..< decl.range.upperBound
        }
        return decl

      case .some(let node):
        issues.append(parseFailure(
          Issue.unexpectedEntity(expected: "property or function declaration", got: node),
          range: node.range))
        return node

      case nil:
        return nil
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
      switch parseDecl(issues: &issues) {
      case nil:
        return nil

      case let decl as PropDecl:
        decl.modifiers = Set(modifiers)
        decl.range = modifiers.first!.range.lowerBound ..< decl.range.upperBound
        return decl

      case let decl as FunDecl:
        decl.modifiers = Set(modifiers)
        decl.range = modifiers.first!.range.lowerBound ..< decl.range.upperBound
        return decl

      case .some(let node):
        issues.append(parseFailure(
          Issue.unexpectedEntity(expected: "property or function declaration", got: node),
          range: node.range))
        return node
      }

    case .let, .var:
      return parsePropDecl(issues: &issues)

    case .fun, .new, .del:
      return parseFunDecl(issues: &issues)

    case .interface:
      return parseInterfaceDecl(issues: &issues)

    case .struct:
      return parseStructDecl(issues: &issues)

    case .union:
      return parseUnionDecl(issues: &issues)

    case .case:
      return parseUnionNestedMemberDecl(issues: &issues)

    case .extension:
      return parseTypeExtDecl(issues: &issues)

    default:
      issues.append(unexpectedToken(expected: "declaration"))
      return nil
    }
  }

  /// Parses a property declaration.
  func parsePropDecl(issues: inout [Issue]) -> PropDecl? {
    // The first token must be `let` or `var`.
    guard let head = consume([.let, .var]) else {
      issues.append(unexpectedToken(expected: "'let'"))
      return nil
    }

    let propDecl = PropDecl(
      name: "__error",
      isReassignable: head.kind == .var,
      module: module,
      range: head.range)

    // Parse the property's name.
    if let nameToken = consume(.identifier, afterMany: .newline) {
      propDecl.name = nameToken.value!
    } else {
      issues.append(unexpectedToken(expected: "identifier"))
    }

    // Attempt to parse a type annotation.
    if consume(.colon, afterMany: .newline) != nil {
      consumeNewlines()
      if let sign = parseQualSign(issues: &issues) {
        propDecl.sign = sign
      }
    }

    // Attempt to parse an initial binding.
    if consume(if: { $0.isBindingOperator || $0.kind == .assign }, afterMany: .newline) != nil {
      rewind()
      if let initializer = parseBinding(issues: &issues) {
        propDecl.initializer = initializer
      } else {
        assertionFailure()
      }
    }

    propDecl.range = head.range.lowerBound ..< lastConsumedToken!.range.upperBound
    return propDecl
  }

  /// Parses a function declaration.
  func parseFunDecl(issues: inout [Issue]) -> FunDecl? {
    let head: Token
    let name: String
    let kind: FunDecl.Kind

    switch peek().kind {
    case .fun:
      head = consume()!
      kind = .regular

      // Parse the function's name.
      if let nameToken = consume(TokenKind.Category.name, afterMany: .newline) {
        if nameToken.isKeyword {
          name = "__error"
          issues.append(
            parseFailure(Issue.keywordAsIdent(keyword: name), range: nameToken.range))
        } else {
          name = nameToken.value!
        }
      } else {
        name = "__error"
        issues.append(unexpectedToken(expected: "identifier"))
      }

    case .new:
      head = consume()!
      name = "new"
      kind = .constructor

    case .del:
      head = consume()!
      name = "del"
      kind = .destructor

    default:
      issues.append(unexpectedToken(expected: "'fun'"))
      return nil
    }

    let funDecl = FunDecl(name: name, kind: kind, module: module, range: head.range)

    // Attempt to parse a list of generic parameter declarations.
    funDecl.genericParams = parseGenericParamDeclList(issues: &issues)

    // Parse a parameter list.
    if consume(.leftParen, afterMany: .newline) != nil {
      funDecl.params = parseList(delimitedBy: .rightParen, issues: &issues, with: parseParamDecl)
      if consume(.rightParen, afterMany: .newline) == nil {
        issues.append(unexpectedToken(expected: "')'"))
      }
    } else {
      issues.append(unexpectedToken(expected: "'('"))
      recover(atNextKinds: [.arrow, .leftBrace])
    }

    // Attempt to parse a codomain.
    if consume(.arrow, afterMany: .newline) != nil {
      consumeNewlines()
      if let sign = parseQualSign(issues: &issues) {
        funDecl.codom = sign
      } else {
        recover(atNextKinds: [.leftBrace, .newline])
      }
    }

    // Attemt to parse a function body.
    if peek(afterMany: .newline)?.kind == .leftBrace {
      consumeNewlines()
      if let body = parseBraceStmt(issues: &issues) {
        funDecl.body = body
      }
    }

    funDecl.range = head.range.lowerBound ..< lastConsumedToken!.range.upperBound
    return funDecl
  }

  /// Parses a parameter declaration.
  func parseParamDecl(issues: inout [Issue]) -> ParamDecl? {
    // Attempt to parse the label and formal name of the parameter, the last being required.
    guard let first = consume([.underscore, .identifier]) else {
      issues.append(unexpectedToken(expected: "identifier"))
      return nil
    }

    let second = consume(.identifier, afterMany: .newline) ?? first
    if second.kind == .underscore {
      issues.append(unexpectedToken(expected: "identifier"))
    }

    let paramDecl = ParamDecl(
      label: first.kind == .underscore ? nil : first.value,
      name: second.value!,
      module: module,
      range: first.range.lowerBound ..< second.range.upperBound)

    // Attempt to parse a type annotation.
    if consume(.colon, afterMany: .newline) != nil {
      consumeNewlines()
      if let sign = parseQualSign(issues: &issues) {
        paramDecl.sign = sign
      }
    }

    // Attempt to Parse a default binding expression.
    if consume(.assign, afterMany: .newline) != nil {
      consumeNewlines()
      if let expr = parseExpr(issues: &issues) {
        paramDecl.defaultValue = expr
      }
    }

    paramDecl.range = first.range.lowerBound ..< lastConsumedToken!.range.upperBound
    return paramDecl
  }

  /// Parses an interface declaration.
  func parseInterfaceDecl(issues: inout [Issue]) -> InterfaceDecl? {
    // The first token should be `interface`.
    guard let head = consume(.interface) else {
      issues.append(unexpectedToken(expected: "'interface'"))
      return nil
    }

    consumeNewlines()
    let nominalTypeDecl = parseNominalTypeDecl(issues: &issues)
    return InterfaceDecl(
      name: nominalTypeDecl.name,
      genericParams: nominalTypeDecl.genericParams,
      body: nominalTypeDecl.body,
      module: module,
      range: head.range.lowerBound ..< lastConsumedToken!.range.upperBound)
  }

  /// Parses a struct declaration.
  func parseStructDecl(issues: inout [Issue]) -> StructDecl? {
    // The first token should be `struct`.
    guard let head = consume(.struct) else {
      issues.append(unexpectedToken(expected: "'struct'"))
      return nil
    }

    consumeNewlines()
    let nominalTypeDecl = parseNominalTypeDecl(issues: &issues)
    return StructDecl(
      name: nominalTypeDecl.name,
      genericParams: nominalTypeDecl.genericParams,
      body: nominalTypeDecl.body,
      module: module,
      range: head.range.lowerBound ..< lastConsumedToken!.range.upperBound)
  }

  /// Parses a union declaration.
  func parseUnionDecl(issues: inout [Issue]) -> UnionDecl? {
    // The first token should be `struct`.
    guard let head = consume(.union) else {
      issues.append(unexpectedToken(expected: "'union'"))
      return nil
    }

    consumeNewlines()
    let nominalTypeDecl = parseNominalTypeDecl(issues: &issues)
    return UnionDecl(
      name: nominalTypeDecl.name,
      genericParams: nominalTypeDecl.genericParams,
      body: nominalTypeDecl.body,
      module: module,
      range: head.range.lowerBound ..< lastConsumedToken!.range.upperBound)
  }

  /// Helper that factorizes nominal type parsing.
  private func parseNominalTypeDecl(issues: inout [Issue]) -> _NominalTypeDecl {
    // Parse the name of the type.
    let name: String
    if let nameToken = consume(.identifier) {
      name = nameToken.value!
    } else {
      name = "__error"
      issues.append(unexpectedToken(expected: "identifier"))
      recover(atNextKinds: [.leftBrace])
    }

    // Attempt to parse a list of generic parameter declarations.
    let genericParams = parseGenericParamDeclList(issues: &issues)

    // Parse the body of the type.
    consumeNewlines()
    let body = parseBraceStmt(issues: &issues)

    // Mark all regular functions as methods.
    if body != nil {
      for stmt in body!.stmts {
        if let methDecl = stmt as? FunDecl, methDecl.kind == .regular {
          methDecl.kind = .method
        }
      }
    }

    return _NominalTypeDecl(name: name, genericParams: genericParams, body: body)
  }

  /// Parses a union nested member declaration.
  func parseUnionNestedMemberDecl(issues: inout [Issue]) -> UnionNestedDecl? {
    // The first token should be `case`.
    guard let head = consume(.case) else {
      issues.append(unexpectedToken(expected: "'case'"))
      return nil
    }

    let nestedDecl: NominalTypeDecl?

    consumeNewlines()
    switch peek().kind {
    case .struct:
      nestedDecl = parseStructDecl(issues: &issues)
    case .union:
      nestedDecl = parseUnionDecl(issues: &issues)
    default:
      nestedDecl = nil
      issues.append(unexpectedToken(expected: "struct or union declaration"))
    }

    if nestedDecl != nil {
      return UnionNestedDecl(
        nestedDecl: nestedDecl!,
        module: module,
        range: head.range.lowerBound ..< nestedDecl!.range.upperBound)
    } else {
      return UnionNestedDecl(
        nestedDecl: StructDecl(
          name: "__error",
          body: nil,
          module: module,
          range: head.range),
        module: module, range: head.range)
    }
  }

  func parseTypeExtDecl(issues: inout [Issue]) -> TypeExtDecl? {
    // The first token should be `extension`.
    guard let head = consume(.extension) else {
      issues.append(unexpectedToken(expected: "'extension'"))
      return nil
    }

    // Parse the declaration's extended type.
    consumeNewlines()
    let sign = parseTypeSign(issues: &issues)
      ?? InvalidSign(module: module, range: head.range)

    // Parse a the declaration's body.
    consumeNewlines()
    let body = parseBraceStmt(issues: &issues)
      ?? BraceStmt(stmts: [], module: module, range: head.range)

    return TypeExtDecl(
      type: sign,
      body: body,
      module: module,
      range: head.range.lowerBound ..< body.range.upperBound)
  }

  /// Parses a list of generic parameter declarations.
  ///
  /// - Note:
  ///   This parser does not consume any token if the next consumable one isn't an opening angle
  ///   bracket (i.e. a generic paramter list's left delimiter).
  func parseGenericParamDeclList(issues: inout [Issue]) -> [GenericParamDecl] {
    if consume(.lt, afterMany: .newline) != nil {
      // Commit to parse a parameter list.
      let params = parseList(delimitedBy: .gt, issues: &issues, with: parseGenericParamDecl)
      if consume(.gt) == nil {
        issues.append(unexpectedToken(expected: "'>'"))
      }
      return params
    } else {
      return []
    }
  }

  /// Parses a generic parameter declarations.
  func parseGenericParamDecl(issues: inout [Issue]) -> GenericParamDecl? {
    if let head = consume(.identifier) {
      return GenericParamDecl(name: head.value!, module: module, range: head.range)
    } else {
      issues.append(unexpectedToken(expected: "identifier"))
      return nil
    }
  }

  /// Parses a declaration attribute.
  func parseDeclAttr(issues: inout [Issue]) -> DeclAttr? {
    // The first token should be an attribute name (i.e. `'@' <name>`).
    guard let head = consume(.attribute) else {
      issues.append(unexpectedToken(expected: "attribute"))
      return nil
    }

    let attrDecl = DeclAttr(name: head.value!, args: [], module: module, range: head.range)

    // Attempt to parse an argument list on the same line.
    if consume(.leftParen) != nil {
      // Commit to parse an argument list.
      attrDecl.args = parseList(delimitedBy: .rightParen, issues: &issues, with: parseDeclAttrArg)
      if consume(.rightParen) == nil {
        issues.append(unexpectedToken(expected: "')'"))
      }
    }

    attrDecl.range = head.range.lowerBound ..< lastConsumedToken!.range.upperBound
    return attrDecl
  }

  /// Parses a declaration attribute's argument.
  func parseDeclAttrArg(issues: inout [Issue]) -> String? {
    if let arg = consume(.identifier) {
      return arg.value
    } else {
      issues.append(unexpectedToken(expected: "identifier"))
      return nil
    }
  }

}

private struct _NominalTypeDecl {

  let name: String
  let genericParams: [GenericParamDecl]
  let body: BraceStmt?

}
