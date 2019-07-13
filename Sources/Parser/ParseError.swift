import AST

/// A syntax error.
///
/// A syntax error is an error that occurs when trying to interpret syntactically invalid code.
public enum SyntaxError: Error, CustomStringConvertible {

  /// Occurs when parsing mapping literals or specialization lists with duplicate keys.
  case duplicateKey(key: String)
  /// Occurs when parsing parameter lists with duplicate entries.
  case duplicateParameter(name: String)
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
    case let .duplicateParameter(name):
      return "duplicate parameter '\(name)'"
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

/// A parse error.
///
/// A parse error occurs when a parser encounters a syntactically invalid sequence of tokens. It
/// describes of a syntax error (its cause) and the location where the latter occured.
public struct ParseError: Error, CustomStringConvertible {

  /// Creates a new parse error instance with the given cause and range.
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
