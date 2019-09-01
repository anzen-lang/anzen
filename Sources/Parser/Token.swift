import AST

/// A category of lexical token.
public enum TokenKind: UInt64, CustomStringConvertible {

  // MARK: Category bits

  public enum Category: UInt64 {

    /// Denotes a literal.
    case lit          = 256
    /// Denotes an identifier, underscore (i.e. `_`) or an first-class operator.
    case name         = 512
    /// Denotes an operator.
    case op           = 1024
    /// Denotes an infix operator.
    case infix        = 2048
    /// Denotes a prefix operator.
    case prefix       = 4096
    /// Denotes a binding operator.
    case binding      = 8192
    /// Denotes punctuation.
    case punct        = 16384
    /// Denotes a reserved keyword.
    case keyword      = 32768
    /// Denotes a statement starter.
    case stmtStarter  = 65536
    /// Denotes a declaration starter.
    case declStarter  = 131072

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

  case identifier   = 512    // name | 0
  case underscore   = 33281  // keyword | name | 1
  case `nullref`    = 33282  // keyword | name | 2

  case `let`        = 164355 // keyword | declStarter | name | 3
  case `var`        = 164356 // keyword | declStarter | name | 4
  case fun          = 164357 // keyword | declStarter | name | 5
  case mutating     = 164358 // keyword | declStarter | name | 6
  case `static`     = 164359 // keyword | declStarter | name | 7
  case `struct`     = 164360 // keyword | declStarter | name | 8
  case union        = 164361 // keyword | declStarter | name | 9
  case interface    = 164362 // keyword | declStarter | name | 10
  case `extension`  = 164363 // keyword | declStarter | name | 11
  case new          = 164364 // keyword | declStarter | name | 12
  case del          = 164365 // keyword | declStarter | name | 13
  case `where`      = 33294  // keyword | name | 14
  case `while`      = 98831  // keyword | stmtStarter | name | 15
  case `for`        = 98832  // keyword | stmtStarter | name | 16
  case `in`         = 33297  // keyword | name | 17
  case `break`      = 98834  // keyword | stmtStarter | name | 18
  case `continue`   = 98835  // keyword | stmtStarter | name | 19
  case `return`     = 98836  // keyword | stmtStarter | name | 20
  case `if`         = 98837  // keyword | stmtStarter | name | 21
  case `else`       = 33302  // keyword | name | 22
  case `switch`     = 98839  // keyword | stmtStarter | name | 23
  case `case`       = 164376 // keyword | declStarter | name | 24

  // MARK: Operators

  case not          = 5697   // prefix | op | name | 65

  case unsafeAs     = 3650   // infix | op | name | 66
  case safeAs       = 3651   // infix | op | name | 67
  case `is`         = 3652   // infix | op | name | 68
  case and          = 3653   // infix | op | name | 69
  case or           = 3654   // infix | op | name | 70
  case add          = 7751   // prefix | infix | op | name | 71
  case sub          = 7752   // prefix | infix | op | name | 72
  case mul          = 3657   // infix | op | name | 73
  case div          = 3658   // infix | op | name | 74
  case mod          = 3659   // infix | op | name | 75
  case lt           = 3660   // infix | op | name | 76
  case le           = 3661   // infix | op | name | 77
  case ge           = 3662   // infix | op | name | 78
  case gt           = 3663   // infix | op | name | 79
  case eq           = 3664   // infix | op | name | 80
  case ne           = 3665   // infix | op | name | 81
  case ellipsis     = 3666   // infix | op | name | 82

  case refeq        = 3155   // infix | op | 83
  case refne        = 3156   // infix | op | 84

  case copy         = 9301   // binding | op | 85
  case alias        = 9302   // binding | op | 86
  case move         = 9303   // binding | op | 87
  case arrow        = 9304   // binding | op | 88

  case assign       = 1112   // op | 89

  // MARK: Punctuation

  case eof          = 16513  // punct | 129
  case newline      = 16514  // punct | 130

  case dot          = 16515  // punct | 131
  case comma        = 16516  // punct | 132
  case exclamation  = 16517  // punct | 133
  case question     = 16518  // punct | 134

  case colon        = 16519  // punct | 135
  case doubleColon  = 16520  // punct | 136
  case semicolon    = 16521  // punct | 137

  case leftParen    = 16522  // punct | 138
  case rightParen   = 16523  // punct | 139
  case leftBrace    = 16524  // punct | 140
  case rightBrace   = 16525  // punct | 141
  case leftBracket  = 82062  // stmtStarter | punct | 142
  case rightBracket = 16527  // punct | 143

  // MARK: Literals

  case bool         = 449    // lit | 193
  case integer      = 450    // lit | 194
  case float        = 451    // lit | 195
  case string       = 452    // lit | 196

  // MARK: Annotations

  case directive    = 225
  case qualifier    = 131298 // declStarter | 226

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
    case .unsafeAs:     return "as!"
    case .safeAs:       return "as?"
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
    case .qualifier:    return "<qualifier>"
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

  /// The kind of the token.
  public let kind: TokenKind
  /// The range of characters that compose the token in the source file.
  public let range: SourceRange

  /// The text represented by this token.
  public var value: String? {
    return try? range.sourceRef.buffer.read(
      count: range.upperBound.offset - range.lowerBound.offset,
      from: range.lowerBound.offset)
  }

  public init(kind: TokenKind, range: SourceRange) {
    self.kind = kind
    self.range = range
  }

  /// Whether or not the token is a statement delimiter.
  public var isStatementDelimiter: Bool {
    return (kind == .newline) || (kind == .semicolon)
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

  /// Whether or not the token is a reserved keyword.
  public var isKeyword: Bool {
    return (kind & TokenKind.Category.keyword) > 0
  }

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
