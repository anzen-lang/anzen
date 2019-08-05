import AST

/// A category of lexical token.
public enum TokenKind: UInt64, CustomStringConvertible {

  // MARK: Category bits

  public enum Category: UInt64 {

    /// Denotes a literal.
    case lit = 256
    /// Denotes an identifier, underscore (i.e. `_`) or an first-class operator.
    case name = 512
    /// Denotes an operator.
    case op = 1024
    /// Denotes an infix operator.
    case infix = 2048
    /// Denotes a prefix operator.
    case prefix = 4096
    /// Denotes a binding operator.
    case binding = 8192
    /// Denotes punctuation.
    case punct = 16384
    /// Denotes a statement starter.
    case stmtStarter = 32768

  }

  public static func | (lhs: TokenKind, rhs: TokenKind) -> UInt64 {
    return lhs.rawValue | rhs.rawValue
  }

  public static func | (lhs: TokenKind, rhs: TokenKind.Category) -> UInt64 {
    return lhs.rawValue | rhs.rawValue
  }

  public static func | (lhs: TokenKind, rhs: UInt64) -> UInt64 {
    return lhs.rawValue | rhs
  }

  public static func & (lhs: TokenKind, rhs: TokenKind) -> UInt64 {
    return lhs.rawValue & rhs.rawValue
  }

  public static func & (lhs: TokenKind, rhs: TokenKind.Category) -> UInt64 {
    return lhs.rawValue & rhs.rawValue
  }

  public static func & (lhs: TokenKind, rhs: UInt64) -> UInt64 {
    return lhs.rawValue & rhs
  }

  // MARK: Identifiers & Keywords

  case identifier   = 512   // name | 0
  case underscore   = 513   // name | 1
  case `nullref`    = 514   // name | 2

  case `let`        = 33283 // stmtStarter | name | 3
  case `var`        = 33284 // stmtStarter | name | 4
  case fun          = 33285 // stmtStarter | name | 5
  case mutating     = 33286 // stmtStarter | name | 6
  case `static`     = 33287 // stmtStarter | name | 7
  case `struct`     = 33288 // stmtStarter | name | 8
  case union        = 33289 // stmtStarter | name | 9
  case interface    = 33290 // stmtStarter | name | 10
  case `extension`  = 33291 // stmtStarter | name | 11
  case new          = 33292 // stmtStarter | name | 12
  case del          = 33293 // stmtStarter | name | 13
  case `where`      = 33294 // stmtStarter | name | 14
  case `while`      = 33295 // stmtStarter | name | 15
  case `for`        = 33296 // stmtStarter | name | 16
  case `in`         = 529   // name | 17
  case `break`      = 33298 // stmtStarter | name | 18
  case `continue`   = 33299 // stmtStarter | name | 19
  case `return`     = 33300 // stmtStarter | name | 20
  case `if`         = 33301 // stmtStarter | name | 21
  case `else`       = 33302 // stmtStarter | name | 22
  case `switch`     = 33303 // stmtStarter | name | 23
  case `case`       = 33304 // stmtStarter | name | 24

  // MARK: Operators

  case not          = 5697  // prefix | op | name | 65

  case `as`         = 3650  // infix | op | name | 66
  case `is`         = 3651  // infix | op | name | 67
  case and          = 3652  // infix | op | name | 68
  case or           = 3653  // infix | op | name | 69
  case add          = 7750  // prefix | infix | op | name | 70
  case sub          = 7751  // prefix | infix | op | name | 71
  case mul          = 3656  // infix | op | name | 72
  case div          = 3657  // infix | op | name | 73
  case mod          = 3658  // infix | op | name | 74
  case lt           = 3659  // infix | op | name | 75
  case le           = 3660  // infix | op | name | 76
  case ge           = 3661  // infix | op | name | 77
  case gt           = 3662  // infix | op | name | 78
  case eq           = 3663  // infix | op | name | 79
  case ne           = 3664  // infix | op | name | 80
  case ellipsis     = 3665  // infix | op | name | 81

  case refeq        = 3154  // infix | op | 82
  case refne        = 3155  // infix | op | 83

  case copy         = 9300  // binding | op | 84
  case alias        = 9301  // binding | op | 85
  case move         = 9302  // binding | op | 86
  case arrow        = 9303  // binding | op | 87

  case assign       = 1112  // op | 88

  // MARK: Punctuation

  case eof          = 16513 // punct | 129
  case newline      = 16514 // punct | 130

  case dot          = 16515 // punct | 131
  case comma        = 16516 // punct | 132
  case exclamation  = 16517 // punct | 133
  case question     = 16518 // punct | 134

  case colon        = 16519 // punct | 135
  case doubleColon  = 16520 // punct | 136
  case semicolon    = 16521 // punct | 137

  case leftParen    = 16522 // punct | 138
  case rightParen   = 16523 // punct | 139
  case leftBrace    = 16524 // punct | 140
  case rightBrace   = 16525 // punct | 141
  case leftBracket  = 49294 // stmtStarter | punct | 142
  case rightBracket = 16527 // punct | 143

  // MARK: Literals

  case bool         = 449   // lit | 193
  case integer      = 450   // lit | 194
  case float        = 451   // lit | 195
  case string       = 452   // lit | 196

  // MARK: Annotations

  case directive    = 225
  case attribute    = 32994 // stmtStarter | 226

  // MARK: Error tokens

  case unterminatedBlockComment = 253
  case unterminatedStringLiteral = 254
  case unknown = 255

  // MARK: CustomStringConvertible

  public var description: String {
    switch self {
    case .identifier:   return "identifier"
    case .underscore:   return "_"
    case .let:          return "let"
    case .var:          return "var"
    case .fun:          return "fun"
    case .mutating:     return "mutating"
    case .static:       return "static"
    case .struct:       return "struct"
    case .union:        return "union"
    case .interface:    return "interface"
    case .extension:    return "extension"
    case .new:          return "new"
    case .del:          return "del"
    case .where:        return "where"
    case .while:        return "while"
    case .for:          return "for"
    case .in:           return "in"
    case .break:        return "break"
    case .continue:     return "continue"
    case .return:       return "return"
    case .if:           return "if"
    case .else:         return "else"
    case .switch:       return "switch"
    case .case:         return "case"
    case .nullref:      return "nullref"
    case .not:          return "not"
    case .as:           return "as"
    case .is:           return "is"
    case .and:          return "and"
    case .or:           return "or"
    case .add:          return "+"
    case .sub:          return "-"
    case .mul:          return "*"
    case .div:          return "/"
    case .mod:          return "%"
    case .lt:           return "<"
    case .le:           return "<="
    case .ge:           return ">="
    case .gt:           return ">"
    case .eq:           return "=="
    case .ne:           return "!="
    case .ellipsis:     return "..."
    case .refeq:        return "==="
    case .refne:        return "!=="
    case .assign:       return "="
    case .copy:         return ":="
    case .alias:        return "&-"
    case .move:         return "<-"
    case .arrow:        return "->"
    case .eof:          return "<eof>"
    case .newline:      return "<newline>"
    case .dot:          return "."
    case .comma:        return ","
    case .exclamation:  return "!"
    case .question:     return "?"
    case .colon:        return ":"
    case .doubleColon:  return "::"
    case .semicolon:    return ";"
    case .leftParen:    return "("
    case .rightParen:   return ")"
    case .leftBrace:    return "{"
    case .rightBrace:   return "}"
    case .leftBracket:  return "["
    case .rightBracket: return "]"
    case .bool:         return "bool"
    case .integer:      return "integer"
    case .float:        return "float"
    case .string:       return "string"
    case .directive:    return "<directive>"
    case .attribute:    return "<attribute>"
    case .unterminatedBlockComment: return "<unterminated comment block>"
    case .unterminatedStringLiteral: return "<unterminated string literal>"
    case .unknown:      return "<unknown>"
    }
  }

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
    return (kind & 255 & (TokenKind.newline | TokenKind.semicolon)) != 0
  }

  /// Whether or not the token is an prefix operator.
  public var isPrefixOperator: Bool {
    return (kind & TokenKind.Category.prefix) > 0
  }

  /// Whether or not the token is a binding operator.
  public var isBindingOperator: Bool {
    return (kind & TokenKind.Category.binding) > 0
  }

  /// Whether or not the token is an infix operator.
  public var isInfixOperator: Bool {
    return (kind & TokenKind.Category.infix) > 0
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
    return kind.description
  }

}

public enum OperatorAssociativity {

  case left
  case right

}
