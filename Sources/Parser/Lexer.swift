import Foundation

import AST
import Utils

/// A lexer for the tokens of the Anzen language.
///
/// This structure provides an interface to turn a text buffer into a stream of tokens. It is
/// intended for forward lexing only, and does not have any support for buffering and/or seeking.
public struct Lexer {

  /// The stream of characters.
  fileprivate var characters: String.UnicodeScalarView
  /// The current character index in the stream.
  fileprivate var charIndex: String.UnicodeScalarView.Index
  /// The current source location of the lexer.
  fileprivate var currentLocation: SourceLocation
  /// Whether or not the stream has been depleted.
  fileprivate var depleted = false

  /// The current character in the stream.
  fileprivate var currentChar: UnicodeScalar? {
    return charIndex < characters.endIndex
      ? characters[charIndex]
      : nil
  }

  /// Creates a new lexer instance for the specified input buffer.
  ///
  /// - Note:
  ///   The lexer currently consume the entire input stream at once and stores its contents in an
  ///   array, in order to simplify forward lookup. This approach might not scale well with large
  ///   inputs, and therefore future versions should implement a more elaborate buffering strategy.
  public init(source: SourceRef) throws {
    currentLocation = SourceLocation(sourceRef: source)
    characters = try source.buffer.read().unicodeScalars
    charIndex = characters.startIndex
  }

  /// Takes the given number of characters from the stream, advancing the lexer.
  mutating func take(_ n: Int = 1) -> String.UnicodeScalarView.SubSequence {
    let startIndex = charIndex
    for _ in 0 ..< n {
      guard let c = currentChar else { return characters[startIndex ... charIndex] }
      if c == "\n" {
        currentLocation.line += 1
        currentLocation.column = 1
      } else {
        currentLocation.column += 1
      }
      currentLocation.offset += 1
      charIndex = characters.index(after: charIndex)
    }
    return characters[startIndex ..< charIndex]
  }

  /// Takes a characters from the stream as long as the predicate holds, advancing the lexer.
  mutating func take(while predicate: (UnicodeScalar) -> Bool)
    -> String.UnicodeScalarView.SubSequence
  {
    let startIndex = charIndex
    while let c = currentChar, predicate(c) {
      _ = take()
    }
    return characters[startIndex ..< charIndex]
  }

  /// Skips the given number of characters in the stream.
  mutating func skip(_ n: Int = 1) {
    _ = take(n)
  }

  /// Skips the characters of the stream while the given predicate holds.
  mutating func skip(while predicate: (UnicodeScalar) -> Bool) {
    while let c = currentChar, predicate(c) {
      skip()
    }
  }

  /// Retrieves the i-th character of the stream.
  func char(at index: Int) -> UnicodeScalar? {
    let forwardIndex = characters.index(charIndex, offsetBy: index)
    return forwardIndex < characters.endIndex
      ? characters[forwardIndex]
      : nil
  }

  /// Returns a source range from the given location to the lexer's current location.
  func range(from start: SourceLocation) -> SourceRange {
    return start ..< currentLocation
  }

}

extension Lexer: IteratorProtocol, Sequence {

  /// Returns the next token.
  public mutating func next() -> Token? {
    guard !depleted else { return nil }

    // Ignore whitespaces.
    skip(while: isWhitespace)

    // Check for the end of file.
    guard let c = currentChar else {
      defer { depleted = true }
      return Token(kind: .eof, range: currentLocation ..< currentLocation.advancedBy(columns: 1))
    }

    // Check for statement delimiters.
    if c == "\n" {
      defer { skip(while: { isWhitespace($0) || isStatementDelimiter($0) }) }
      let start = currentLocation
      skip()
      return Token(kind: .newline, range: start ..< currentLocation)
    }
    if c == ";" {
      defer { skip(while: { isWhitespace($0) || isStatementDelimiter($0) }) }
      let start = currentLocation
      skip()
      return Token(kind: .semicolon, range: start ..< currentLocation)
    }

    let startLocation = currentLocation

    // Skip comments.
    if c == "/" {
      let nextChar = char(at: 1)

      // We found a line comment.
      if nextChar == "/" {
        skip(while: { $0 != "\n" })
        return self.next()
      }

      // We found a block comment.
      if nextChar == "*" {
        skip(2)
        while currentChar != "*" || char(at: 1) != "/" {
          // Make sure the stream isn't depleted.
          guard charIndex < characters.endIndex else {
            depleted = true
            skip(while: { _ in true })
            return Token(kind: .unterminatedBlockComment, range: range(from: startLocation))
          }
          skip()
        }
        skip(2)
        return self.next()
      }
    }

    // Check for number literals.
    if isDigit(c) {
      _ = take(while: isDigit)

      // Check for float literals.
      if currentChar == "." && (char(at: 1).map(isDigit) ?? false) {
        skip()
        _ = take(while: isDigit)
        return Token(
          kind: .float,
          range: range(from: startLocation))
      }

      return Token(kind: .integer, range: range(from: startLocation))
    }

    // Check for identifiers.
    if isAlnumOrUnderscore(c) {
      var chars = String(take(while: isAlnumOrUnderscore))
      let kind: TokenKind

      // Check for keywords and operators.
      switch chars {
      case "_"        : kind = .underscore
      case "true"     : kind = .bool
      case "false"    : kind = .bool
      case "not"      : kind = .not
      case "is"       : kind = .is
      case "and"      : kind = .and
      case "or"       : kind = .or
      case "let"      : kind = .let
      case "var"      : kind = .var
      case "fun"      : kind = .fun
      case "mutating" : kind = .mutating
      case "static"   : kind = .static
      case "struct"   : kind = .struct
      case "union"    : kind = .union
      case "interface": kind = .interface
      case "extension": kind = .extension
      case "new"      : kind = .new
      case "del"      : kind = .del
      case "where"    : kind = .where
      case "while"    : kind = .while
      case "for"      : kind = .for
      case "in"       : kind = .in
      case "break"    : kind = .break
      case "continue" : kind = .continue
      case "return"   : kind = .return
      case "if"       : kind = .if
      case "else"     : kind = .else
      case "switch"   : kind = .switch
      case "case"     : kind = .case
      case "nullref"  : kind = .nullref
      default:
        if (currentChar == "!") || (currentChar == "?") {
          // Append the `!` or `?` suffix for cast operators and other identifiers.
          chars.append(String(take()))
        }
        switch chars {
        case "as!": kind = .unsafeAs
        case "as?": kind = .safeAs
        default   : kind = .identifier
        }
      }

      return Token(kind: kind, range: range(from: startLocation))
    }

    // Check for string literals.
    if c == "\"" {
      skip()

      while currentChar != "\"" {
        // Make sure the stream isn't depleted.
        guard charIndex < characters.endIndex else {
          depleted = true
          skip(while: { _ in true })
          return Token(kind: .unterminatedStringLiteral, range: range(from: startLocation))
        }
        skip()

        // Skip escaped end quotes.
        if (currentChar == "\\") && (char(at: 1) == "\"") {
          skip(2)
        }
      }

      skip()
      return Token(kind: .string, range: range(from: startLocation))
    }

    // Check for qualifiers.
    if c == "@" {
      skip()
      _ = take(while: isAlnumOrUnderscore)
      return Token(kind: .attribute, range: range(from: startLocation))
    }

    // Check for directives.
    if c == "#" {
      skip()
      _ = take(while: isAlnumOrUnderscore)
      return Token(kind: .directive, range: range(from: startLocation))
    }

    // Check for operators.
    if OPERATOR_CHARS.contains(c) {
      // Check for operators made of a 3 characters.
      if let c1 = char(at: 1), let c2 = char(at: 2) {
        let value = String(c) + String(c1) + String(c2)
        var kind: TokenKind?

        switch value {
        case "===": kind = .refeq
        case "!==": kind = .refne
        case "...": kind = .ellipsis
        default   : break
        }

        if kind != nil {
          skip(3)
          return Token(kind: kind!, range: range(from: startLocation))
        }
      }

      // Check for operators made of 2 characters.
      if let c1 = char(at: 1) {
        let value = String(c) + String(c1)
        var kind: TokenKind?

        switch value {
        case ":=": kind = .copy
        case "&-": kind = .alias
        case "<-": kind = .move
        case "->": kind = .arrow
        case "<=": kind = .le
        case ">=": kind = .ge
        case "==": kind = .eq
        case "!=": kind = .ne
        case "::": kind = .doubleColon
        default  : break
        }

        if kind != nil {
          skip(2)
          return Token(kind: kind!, range: range(from: startLocation))
        }
      }

      // Check for operators made of a single character.
      let kind: TokenKind

      switch c {
      case ".": kind = .dot
      case ",": kind = .comma
      case ":": kind = .colon
      case "!": kind = .exclamation
      case "?": kind = .question
      case "(": kind = .leftParen
      case ")": kind = .rightParen
      case "{": kind = .leftBrace
      case "}": kind = .rightBrace
      case "[": kind = .leftBracket
      case "]": kind = .rightBracket
      case "=": kind = .assign
      case "<": kind = .lt
      case ">": kind = .gt
      case "+": kind = .add
      case "-": kind = .sub
      case "*": kind = .mul
      case "/": kind = .div
      case "%": kind = .mod
      default : kind = .unknown
      }

      skip()
      return Token(kind: kind, range: range(from: startLocation))
    }

    skip()
    return Token(kind: .unknown, range: range(from: startLocation))
  }

}

/// Returns whether or not the given character is a whitespace.
private func isWhitespace(_ char: UnicodeScalar) -> Bool {
  return char == " " || char == "\t"
}

/// Returns whether or not the given character is a statement delimiter.
private func isStatementDelimiter(_ char: UnicodeScalar) -> Bool {
  return char == "\n" || char == ";"
}

/// Returns whether or not the given charater is a digit.
private func isDigit(_ char: UnicodeScalar) -> Bool {
  return CharacterSet.decimalDigits.contains(char)
}

/// Returns whetehr or not the given character is an alphanumeric characters, or `_`.
private func isAlnumOrUnderscore(_ char: UnicodeScalar) -> Bool {
  return char == "_" || CharacterSet.alphanumerics.contains(char)
}

/// Set of operator symbols.
private let OPERATOR_CHARS = Set<UnicodeScalar>(".,:!?(){}[]<>-*/%+-=&".unicodeScalars)
