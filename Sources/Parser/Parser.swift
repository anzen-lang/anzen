import AST
import Utils

public class Parser {

  /// Initializes a parser with a token stream.
  ///
  /// - Note: The token stream must have at least one token and ends with `.eof`.
  public init<S>(_ tokens: S) where S: Sequence, S.Element == Token {
    self.stream = Array(tokens)
    assert((self.stream.count > 0) && (self.stream.last!.kind == .eof), "invalid token stream")
  }

  /// Initializes a parser from a source file.
  convenience public init(file: File) {
    self.init(Lexer(file: file))
  }

  /// Parses the token stream into a module declaration.
  public func parse() throws -> ModuleDecl {
    var statements: [Node] = []

    while true {
      // Skip statement delimiters.
      consumeMany { $0.isStatementDelimiter }
      // Check for end of file.
      guard peek().kind != .eof else { break }
      // Parse a statement.
      statements.append(try parseStatement())
    }

    let range = statements.isEmpty
      ? SourceRange(at: SourceLocation())
      : SourceRange(from: statements.first!.range.start, to: statements.last!.range.end)
    return ModuleDecl(statements: statements, range: range)
  }

  /// Attempts to run the given parsing function but backtracks if it failed.
  func attempt<Result>(_ parse: () throws -> Result) -> Result? {
    let backtrackingPosition = streamPosition
    guard let result = try? parse() else {
      rewind(to: backtrackingPosition)
      return nil
    }
    return result
  }

  /// Parses a list of elements, separated by a `,`.
  ///
  /// This helper will parse a list of elements, separated by a `,` and optionally ending with one,
  /// until it finds `delimiter`. New lines before and after each element will be consumed, but the
  /// delimiter won't.
  func parseList<Element>(
    delimitedBy delimiter: TokenKind,
    parsingElementWith parse: () throws -> Element)
    rethrows -> [Element]
  {
    // Skip leading new lines.
    consumeMany { $0.kind == .newline }

    // Parse as many elements as possible.
    var elements: [Element] = []
    while peek().kind != delimiter {
      // Parse an element.
      try elements.append(parse())

      // If the next consumable token isn't a separator, stop parsing here.
      consumeNewlines()
      if consume(.comma) == nil {
        break
      }

      // Skip trailing new after the separator.
      consumeNewlines()
    }

    return elements
  }

  /// Tiny helper to build parse errors.
  func parseFailure(_ syntaxError: SyntaxError, range: SourceRange? = nil) -> ParseError {
    return ParseError(syntaxError, range: range ?? peek().range)
  }

  /// Tiny helper to build unexpected token errors.
  func unexpectedToken(expected: String? = nil, got token: Token? = nil) -> ParseError {
    let t = token ?? peek()
    return ParseError(.unexpectedToken(expected: expected, got: t), range: t.range)
  }

  /// The stream of tokens.
  var stream: [Token]
  /// The current position in the token stream.
  var streamPosition: Int = 0

}

extension Parser {

  /// Returns the token 1 position ahead, without consuming the stream.
  func peek() -> Token {
    assert((streamPosition) < stream.count)
    return stream[streamPosition]
  }

  /// Attempts to consume a single token.
  @discardableResult
  func consume() -> Token? {
    guard streamPosition < stream.count
      else { return nil }
    defer { streamPosition += 1 }
    return stream[streamPosition]
  }

  /// Attempts to consume a single token of the given kind from the stream.
  @discardableResult
  func consume(_ kind: TokenKind) -> Token? {
    guard (streamPosition < stream.count) && (stream[streamPosition].kind == kind)
      else { return nil }
    defer { streamPosition += 1 }
    return stream[streamPosition]
  }

  /// Attempts to consume a single token of the given kind, after a sequence of specific tokens.
  @discardableResult
  func consume(_ kind: TokenKind, afterMany skipKind: TokenKind) -> Token? {
    let backtrackPosition = streamPosition
    consumeMany { $0.kind == skipKind }
    if let result = consume(kind) {
      return result
    }
    rewind(to: backtrackPosition)
    return nil
  }

  /// Attemps to consume a single token, if it satisfies the given predicate.
  @discardableResult
  func consume(if predicate: (Token) throws -> Bool) rethrows -> Token? {
    guard try (streamPosition < stream.count) && predicate(stream[streamPosition])
      else { return nil }
    defer { streamPosition += 1 }
    return stream[streamPosition]
  }

  /// Consumes up to the given number of elements from the stream.
  @discardableResult
  func consumeMany(upTo n: Int = 1) -> ArraySlice<Token> {
    let consumed = stream[streamPosition ..< streamPosition + n]
    streamPosition += consumed.count
    return consumed
  }

  /// Consumes tokens from the stream as long as they satisfy the given predicate.
  @discardableResult
  func consumeMany(while predicate: (Token) throws -> Bool) rethrows -> ArraySlice<Token> {
    let consumed: ArraySlice = try stream[streamPosition...].prefix(while: predicate)
    streamPosition += consumed.count
    return consumed
  }

  /// Consume new lines.
  func consumeNewlines() {
    for token in stream[streamPosition...] {
      guard token.kind == .newline else { break }
      streamPosition += 1
    }
  }

  /// Rewinds the token stream by the given number of positions.
  func rewind(_ n: Int = 1) {
    streamPosition = Swift.max(streamPosition - 1, 0)
  }

  /// Rewinds the stream to the specified position.
  func rewind(to position: Int) {
    streamPosition = position
  }
}
