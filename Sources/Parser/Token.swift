import AST

/// A category of lexical token.
public enum TokenKind: CustomStringConvertible {

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
  case add
  case sub
  case mul
  case div
  case mod
  case lt
  case le
  case ge
  case gt
  case eq
  case ne
  case refeq
  case refne
  case assign
  case copy
  case alias
  case move
  case arrow

  case dot
  case comma
  case colon
  case doubleColon
  case semicolon
  case exclamationMark
  case questionMark
  case ellipsis
  case newline
  case eof

  case leftParen
  case rightParen
  case leftBrace
  case rightBrace
  case leftBracket
  case rightBracket

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

  case directive
  case attribute

  // MARK: Error tokens

  case unknown
  case unterminatedBlockComment
  case unterminatedStringLiteral

  public var description: String {
    switch self {
    case .bool:                       return "bool"
    case .integer:                    return "integer"
    case .float:                      return "float"
    case .string:                     return "string"

    case .identifier:                 return "identifier"
    case .underscore:                 return "_"

    case .as:                         return "as"
    case .is:                         return "is"
    case .not:                        return "not"
    case .and:                        return "and"
    case .or:                         return "or"
    case .add:                        return "+"
    case .sub:                        return "-"
    case .mul:                        return "*"
    case .div:                        return "/"
    case .mod:                        return "%"
    case .lt:                         return "<"
    case .le:                         return "<="
    case .ge:                         return ">="
    case .gt:                         return ">"
    case .eq:                         return "=="
    case .ne:                         return "!="
    case .refeq:                      return "==="
    case .refne:                      return "!=="
    case .assign:                     return "="
    case .copy:                       return ":="
    case .alias:                      return "&-"
    case .move:                       return "<-"
    case .arrow:                      return "->"

    case .dot:                        return "."
    case .comma:                      return ","
    case .colon:                      return ":"
    case .doubleColon:                return "::"
    case .semicolon:                  return ";"
    case .exclamationMark:            return "!"
    case .questionMark:               return "?"
    case .ellipsis:                   return "..."
    case .newline:                    return "<newline>"
    case .eof:                        return "<eof>"

    case .leftParen:                  return "("
    case .rightParen:                 return ")"
    case .leftBrace:                  return "{"
    case .rightBrace:                 return "}"
    case .leftBracket:                return "["
    case .rightBracket:               return "]"

    case .let:                        return "let"
    case .var:                        return "var"
    case .fun:                        return "fun"
    case .mutating:                   return "mutating"
    case .static:                     return "static"
    case .struct:                     return "struct"
    case .union:                      return "union"
    case .interface:                  return "interface"
    case .extension:                  return "extension"
    case .new:                        return "new"
    case .del:                        return "del"
    case .where:                      return "where"
    case .while:                      return "while"
    case .for:                        return "for"
    case .in:                         return "in"
    case .break:                      return "break"
    case .continue:                   return "continue"
    case .return:                     return "return"
    case .if:                         return "if"
    case .else:                       return "else"
    case .switch:                     return "switch"
    case .case:                       return "case"
    case .nullref:                    return "nullref"

    case .directive:                  return "<directive>"
    case .attribute:                  return "<attribute>"

    case .unknown:                    return "<unknown>"
    case .unterminatedBlockComment:   return "<unterminated comment block>"
    case .unterminatedStringLiteral:  return "<unterminated string literal>"
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
    return kind.description
  }

}

public enum OperatorAssociativity {

  case left
  case right

}
