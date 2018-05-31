import AST
import Utils

extension Parser {

  /// Parses a property declaration.
  func parsePropDecl() throws -> PropDecl {
    guard let startToken = consume(if: { $0.kind == .let || $0.kind == .var })
      else { throw unexpectedToken(expected: "let") }

    // Parse the name of the property.
    guard let name = consume(.identifier, afterMany: .newline)
      else { throw parseFailure(.expectedIdentifier) }
    var end = name.range.end

    // Parse the optional type annotation.
    var annotation: QualSign? = nil
    if consume(.colon, afterMany: .newline) != nil {
      consumeNewlines()
      annotation = try parseQualSign()
      end = annotation!.range.end
    }

    // Parse the optional initial binding value.
    var initialBinding: (op: BindingOperator, value: Expr)? = nil
    let backtrackPosition = streamPosition
    consumeNewlines()
    if let op = consume()?.asBindingOperator {
      consumeNewlines()
      let value = try parseExpression()
      initialBinding = (op, value)
      end = value.range.end
    } else {
      rewind(to: backtrackPosition)
    }

    return PropDecl(
      name: name.value!, reassignable: startToken.kind == .var, typeAnnotation: annotation,
      initialBinding: initialBinding,
      range: SourceRange(from: startToken.range.start, to: end))
  }

  /// Parses a function declaration.
  func parseFunDecl() throws -> FunDecl {
    guard let startToken = consume(.fun)
      else { throw unexpectedToken(expected: "fun") }

    // Parse the name of the function.
    let name: String
    consumeNewlines()
    if let id = consume(.identifier) {
      name = id.value!
    } else if let op = consume(if: { $0.isPrefixOperator }) {
      name = op.asPrefixOperator!.description
    } else if let op = consume(if: { $0.isInfixOperator }) {
      name = op.asInfixOperator!.description
    } else {
      throw parseFailure(.expectedIdentifier)
    }

    // Parse the optional list of generic placeholders.
    var placeholders: [String] = []
    if consume(.lt, afterMany: .newline) != nil {
      let keys = try parseList(delimitedBy: .comma) { () -> Token in
        guard let name = consume(.identifier)
          else { throw parseFailure(.expectedIdentifier) }
        return name
      }

      // Make sure there's no duplicate key.
      let duplicates = keys.duplicates { $0.value! }
      guard duplicates.isEmpty else {
        let key = duplicates.first!
        throw ParseError(.duplicateKey(key: key.value!), range: key.range)
      }

      // Consume the delimiter of the list.
      guard consume(.gt) != nil
        else { throw unexpectedToken(expected: ">") }

      placeholders = keys.map { $0.value! }
    }

    // Parse the parameter list.
    guard consume(.leftParen, afterMany: .newline) != nil
      else { throw unexpectedToken(expected: "(") }
    let parameters = try parseList(delimitedBy: .rightParen, parsingElementWith: parseParamDecl)
    guard var end = consume(.rightParen)?.range.end
      else { throw unexpectedToken(expected: ")") }

    // Parse the optional codomain.
    var codomain: Node? = nil
    if consume(.arrow, afterMany: .newline) != nil {
      consumeNewlines()
      codomain = try parseQualSign()
      end = codomain!.range.end
    }

    // Parse the optional function body.
    let backtrackPosition = streamPosition
    consumeNewlines()
    let block = try? parseStatementBlock()
    if block == nil {
      rewind(to: backtrackPosition)
    } else {
      end = block!.range.end
    }

    return FunDecl(
      name: name, placeholders: placeholders, parameters: parameters, codomain: codomain,
      body: block,
      range: SourceRange(from: startToken.range.start, to: end))
  }

  /// Parses a parameter declaration.
  func parseParamDecl() throws -> ParamDecl {
    // Attempt to parse the label and formal name of the parameter, the last being required.
    guard let first = consume(.underscore) ?? consume(.identifier)
      else { throw unexpectedToken(expected: "identifier") }
    let second = consume(.identifier, afterMany: .newline) ?? first
    guard second.kind != .underscore
      else { throw parseFailure(.expectedIdentifier) }
    var end = second.range.end

    // Parse the optional type annotation.
    var annotation: QualSign? = nil
    if consume(.colon, afterMany: .newline) != nil {
      consumeNewlines()
      annotation = try parseQualSign()
      end = annotation!.range.end
    }

    // Parse the optional initial binding value.
    var defaultValue: Expr? = nil
    let backtrackPosition = streamPosition
    if consume(.copy, afterMany: .newline) != nil {
      consumeNewlines()
      defaultValue = try parseExpression()
      end = defaultValue!.range.end
    } else {
      rewind(to: backtrackPosition)
    }

    let label = first.kind == .underscore
      ? nil
      : first.value

    return ParamDecl(
      label: label,
      name: second.value!,
      typeAnnotation: annotation,
      defaultValue: defaultValue,
      range: SourceRange(from: first.range.start, to: end))
  }

  /// Parses a struct declaration.
  func parseStructDecl() throws -> StructDecl {
    guard let startToken = consume(.struct)
      else { throw unexpectedToken(expected: "struct") }

    let type = try parseNominalType()

    return StructDecl(
      name: type.name, placeholders: type.placeholders, body: type.body,
      range: SourceRange(from: startToken.range.start, to: type.body.range.end))
  }

  /// Parses an interface declaration.
  func parseInterfaceDecl() throws -> InterfaceDecl {
    guard let startToken = consume(.interface)
      else { throw unexpectedToken(expected: "interface") }

    let type = try parseNominalType()

    return InterfaceDecl(
      name: type.name, placeholders: type.placeholders, body: type.body,
      range: SourceRange(from: startToken.range.start, to: type.body.range.end))
  }

  /// Helper that factorizes nominal type parsing.
  func parseNominalType() throws -> NominalType {
    // Parse the name of the type.
    guard let name = consume(.identifier, afterMany: .newline)?.value
      else { throw parseFailure(.expectedIdentifier) }

    // Parse the optional list of generic placeholders.
    var placeholders: [String] = []
    if consume(.lt, afterMany: .newline) != nil {
      let keys = try parseList(delimitedBy: .comma) { () -> Token in
        guard let name = consume(.identifier)
          else { throw parseFailure(.expectedIdentifier) }
        return name
      }

      // Make sure there's no duplicate key.
      let duplicates = keys.duplicates { $0.value! }
      guard duplicates.isEmpty else {
        let key = duplicates.first!
        throw ParseError(.duplicateKey(key: key.value!), range: key.range)
      }

      // Consume the delimiter of the list.
      guard consume(.gt) != nil
        else { throw unexpectedToken(expected: ">") }

      placeholders = keys.map { $0.value! }
    }

    // Parse the body of the type.
    consumeNewlines()
    let body = try parseStatementBlock()

    return NominalType(name: name, placeholders: placeholders, body: body)
  }

}

struct NominalType {

  let name: String
  let placeholders: [String]
  let body: Block

}
