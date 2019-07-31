import AST

/// A category of lexical token.
public enum TokenKind: String {

  // MARK: Literals

  case bool
  case integer
  case float
  case string

  // MARK: Identifiers

  case identifier
  case underscore

  // MARK: Operators

  case `as`
  case `is`
  case not
  case and
  case or
  case add              = "+"
  case sub              = "-"
  case mul              = "*"
  case div              = "/"
  case mod              = "%"
  case lt               = "<"
  case le               = "<="
  case ge               = ">="
  case gt               = ">"
  case eq               = "=="
  case ne               = "!="
  case refeq            = "==="
  case refne            = "!=="
  case assign           = "="
  case copy             = ":="
  case alias            = "&-"
  case move             = "<-"
  case arrow            = "->"

  case dot              = "."
  case comma            = ","
  case colon            = ":"
  case doubleColon      = "::"
  case semicolon        = ";"
  case exclamationMark  = "!"
  case questionMark     = "?"
  case ellipsis         = "..."
  case hashMark         = "#"
  case newline
  case eof

  case leftParen        = "("
  case rightParen       = ")"
  case leftBrace        = "{"
  case rightBrace       = "}"
  case leftBracket      = "["
  case rightBracket     = "]"

  // MARK: Keywords

  case `let`
  case `var`
  case fun
  case mutating
  case `static`
  case `struct`
  case union
  case interface
  case `extension`
  case new
  case del
  case `where`
  case `while`
  case `for`
  case `in`
  case `break`
  case `continue`
  case `return`
  case `if`
  case `else`
  case `switch`
  case `case`
  case `nullref`

  // MARK: Annotations

  case qualifier

  // MARK: Error tokens

  case unknown
  case unterminatedBlockComment
  case unterminatedStringLiteral

}

/// A lexical token of the Anzen language.
///
/// A lexical token is a chunk of the text input to which a syntactic meaning is assigned.
public struct Token {

  public init(kind: TokenKind, value: String? = nil, range: SourceRange) {
    self.kind = kind
    self.value = value
    self.range = range
  }

  /// Whether or not the token is a statement delimiter.
  public var isStatementDelimiter: Bool {
    return kind == .newline || kind == .semicolon
  }

  /// Whether or not the token is an prefix operator.
  public var isPrefixOperator: Bool {
    switch kind {
    case .not, .add, .sub:
      return true
    default:
      return false
    }
  }

  /// Whether or not the token is a binding operator.
  public var isBindingOperator: Bool {
    switch kind {
    case .copy, .alias, .move:
      return true
    default:
      return false
    }
  }

  /// Whether or not the token is an infix operator.
  public var isInfixOperator: Bool {
    switch kind {
    case .as, .mul, .div, .mod, .add, .sub, .lt, .le, .ge, .gt, .eq, .ne, .refeq, .refne, .is,
         .and, .or:
      return true
    default:
      return false
    }
  }

  /// The kind of the token.
  public let kind: TokenKind
  /// The optional value of the token.
  public let value: String?
  /// The range of characters that compose the token in the source file.
  public let range: SourceRange

}

extension Token: Equatable {

  public static func == (lhs: Token, rhs: Token) -> Bool {
    return (lhs.kind == rhs.kind) && (lhs.value == rhs.value) && (lhs.range == rhs.range)
  }

}

extension Token: CustomStringConvertible {

  public var description: String {
    return kind.rawValue
  }

}

public enum OperatorAssociativity {

  case left
  case right

}
