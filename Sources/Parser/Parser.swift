import AST
import Utils

/// A recursive descent parser for the Anzen language.
///
/// This structure provides an interface to turn a stream of tokens into an AST.
///
/// In order to create the most complete error reports possible, the parser does not stop when it
/// encounters a syntax error. Instead, it saves the error before moving into a "degraded" mode in
/// which it skips tokens until it can find the beginning the next construct. It follows that the
/// result of an input's parsing is a (possibly incomplete) AST and a set of errors.
public class Parser {

  /// The result of construction's parsing.
  public struct Result<T> {

    public let value: T
    public let errors: [ParseError]

  }

  /// Initializes a parser with a token stream.
  ///
  /// - Note: The token stream must have at least one token and ends with `.eof`.
  public init<S>(_ tokens: S) where S: Sequence, S.Element == Token {
    let stream = Array(tokens)
    assert((stream.count > 0) && (stream.last!.kind == .eof), "invalid token stream")
    self.stream = stream
    self.module = ModuleDecl(statements: [], range: self.stream.first!.range)
  }

  /// Initializes a parser from a text input.
  public convenience init(source: TextInputBuffer) throws {
    self.init(try Lexer(source: source))
  }

  /// Parses the token stream into a module declaration.
  public func parse() -> Result<ModuleDecl> {
    var errors: [ParseError] = []

    while true {
      // Skip statement delimiters.
      consumeMany { $0.isStatementDelimiter }

      // Check for end of file.
      guard peek().kind != .eof else { break }

      // Parse a statement.
      let parseResult = parseStatement()
      errors.append(contentsOf: parseResult.errors)
      if let statement = parseResult.value {
        module.statements.append(statement)
      }
    }

    module.range = module.statements.isEmpty
      ? self.stream.last!.range
      : SourceRange(
        from: module.statements.first!.range.start,
        to: module.statements.last!.range.end)

    return Result(value: module, errors: errors)
  }

  /// Attempts to run the given parsing function but backtracks if it failed.
  @available(*, deprecated)
  func attempt<R>(_ parse: () throws -> R) -> R? {
    let backtrackingPosition = streamPosition
    guard let result = try? parse() else {
      rewind(to: backtrackingPosition)
      return nil
    }
    return result
  }

  /// Attempts to run the given parsing function but backtracks if it failed.
  func attempt<T>(_ parse: () -> Result<T?>) -> Result<T>? {
    let backtrackingPosition = streamPosition
    let parseResult = parse()
    guard let node = parseResult.value else {
      rewind(to: backtrackingPosition)
      return nil
    }
    return Result(value: node, errors: parseResult.errors)
  }

  /// Parses a list of elements, separated by a `,`.
  ///
  /// This helper will parse a list of elements, separated by a `,` and optionally ending with one,
  /// until it finds `delimiter`. New lines before and after each element will be consumed, but the
  /// delimiter won't.
  func parseList<Element>(
    delimitedBy delimiter: TokenKind,
    parsingElementWith parse: () throws -> Result<Element?>)
    rethrows -> Result<[Element]>
  {
    // Skip leading new lines.
    consumeNewlines()

    var elements: [Element] = []
    var errors: [ParseError] = []

    // Parse as many elements as possible.
    while peek().kind != delimiter {
      // Parse an element.
      let elementParseResult = try parse()

      errors.append(contentsOf: elementParseResult.errors)
      if let element = elementParseResult.value {
        elements.append(element)
      }

      // If the next consumable token isn't a separator, stop parsing here.
      consumeNewlines()
      if consume(.comma) == nil {
        break
      }

      // Skip trailing new lines after the separator.
      consumeNewlines()
    }

    return Result(value: elements, errors: errors)
  }

  /// Tiny helper to build parse errors.
  func parseFailure(_ syntaxError: SyntaxError, range: SourceRange? = nil) -> ParseError {
    return ParseError(syntaxError, range: range ?? peek().range)
  }

  /// Tiny helper to build unexpected construction errors.
  func unexpectedConstruction(expected: String? = nil, got node: Node) -> ParseError {
    return ParseError(.unexpectedConstruction(expected: expected, got: node), range: node.range)
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
  /// The module being parser.
  var module: ModuleDecl

}

extension Parser {

  /// Returns the token 1 position ahead, without consuming the stream.
  func peek() -> Token {
    guard streamPosition < stream.count
      else { return stream.last! }
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

  /// Attempts to consume a single token of the given kinds from the stream.
  @discardableResult
  func consume(_ kinds: Set<TokenKind>) -> Token? {
    guard (streamPosition < stream.count) && (kinds.contains(stream[streamPosition].kind))
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

  /// Attemps to consume a single token, if it satisfies the given predicate, after a sequence of
  /// specific tokens.
  @discardableResult
  func consume(afterMany skipKind: TokenKind, if predicate: (Token) throws -> Bool)
    rethrows -> Token?
  {
    let backtrackPosition = streamPosition
    consumeMany { $0.kind == skipKind }
    if let result = try consume(if: predicate) {
      return result
    }
    rewind(to: backtrackPosition)
    return nil
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

  /// Consume all tokens until the next statement delimiter.
  func consumeUpToNextStatementDelimiter() {
    consumeMany(while: { !$0.isStatementDelimiter && ($0.kind != .eof) })
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
