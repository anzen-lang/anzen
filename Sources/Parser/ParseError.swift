import AST

public enum SyntaxError: Error, CustomStringConvertible {

  /// Occurs when parsing mapping literals or specialization lists with duplicate keys.
  case duplicateKey(key: String)
  /// Occurs when the parser fails to parse an identifier.
  case expectedIdentifier
  /// Occurs when the parser fails to parse the member of a select expression.
  case expectedMember
  /// Occurs when the parser fails to parse a statement delimiter.
  case expectedStatementDelimiter
  /// Occurs when the parses fails to parse a qualifier.
  case invalidQualifier(value: String)
  /// Occurs when the parser unexpectedly depletes the stream.
  case unexpectedEOS
  /// Occurs when the parser encounters an unexpected token.
  case unexpectedToken(expected: String?, got: Token)

  public var description: String {
    switch self {
    case let .duplicateKey(key):
      return "duplicate key '\(key)'"
    case .expectedIdentifier:
      return "expected identifier"
    case .expectedMember:
      return "expected member name following '.'"
    case .expectedStatementDelimiter:
      return "consecutive statements should be separated by ';'"
    case let .invalidQualifier(value):
      return "invalid qualifier '\(value)'"
    case .unexpectedEOS:
      return "unexpected end of stream"
    case let .unexpectedToken(expected: expected, got: found):
      return expected != nil
        ? "expected '\(expected!)', found '\(found)'"
        : "unexpected token '\(found)'"
    }
  }

}

public struct ParseError: Error, CustomStringConvertible {

  public init(_ cause: SyntaxError, range: SourceRange) {
    self.cause = cause
    self.range = range
  }

  public let cause: SyntaxError
  public let range: SourceRange

  public var description: String {
    return cause.description
  }

}
