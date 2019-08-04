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

    /// The parsed entity.
    public let value: T
    /// The issues related to the entity's parsing.
    public let issues: [Issue]

  }

  /// The token stream.
  private var stream: [Token]
  /// Whether the token stream corresponds to the main code declaration.
  private var isMainCodeDecl: Bool
  /// The module being parser.
  internal var module: Module
  /// The current position in the token stream.
  internal var streamPosition: Int = 0

  /// Initializes a parser with a token stream.
  ///
  /// - Parameters:
  ///   - tokens: A token stream.
  ///   - module: The module in which the source of the token stream is defined.
  ///   - isMainCodeDecl: Whether the token stream corresponds to the main code declaration.
  ///
  /// - Note:
  ///   The parser currently consume the entire token stream at once and stores its contents in an
  ///   array, in order to simplify backtracking. This approach might not scale well with large
  ///   inputs, and therefore future versions should implement a more elaborate buffering strategy.
  ///
  /// - Note:
  ///   The token stream must have at least one token and ends with `.eof`.
  public init<S>(_ tokens: S, module: Module, isMainCodeDecl: Bool = false)
    where S: Sequence, S.Element == Token
  {
    let stream = Array(tokens)
    assert((stream.count > 0) && (stream.last!.kind == .eof), "invalid token stream")
    self.stream = stream
    self.module = module
    self.isMainCodeDecl = isMainCodeDecl
  }

  /// Initializes a parser from a text input.
  public convenience init(source: SourceRef, module: Module, isMainCodeDecl: Bool = false) throws {
    self.init(try Lexer(source: source), module: module, isMainCodeDecl: isMainCodeDecl)
  }

  /// Parses the token stream into a collection of top-level declarations.
  public func parse() -> Result<[Decl]> {
    var nodes: [ASTNode] = []
    var issues: [Issue] = []

    // Parse as many nodes as possible.
    while peek().kind != .eof {
      // Skip leading new lines in front of the next element to avoid triggering an error if the
      // end of the sequence has been reached.
      consumeNewlines()
      guard peek().kind != .eof
        else { break }

      // Parse the next node.
      let nodeParseResult = parseTopLevelNode()
      issues.append(contentsOf: nodeParseResult.issues)
      if let node = nodeParseResult.value {
        nodes.append(node)
      } else {
        // If the next node couldn't be parsed, skip all input until the next statement delimiter.
        consumeUpToNextStatementDelimiter()
      }

      if peek().kind != .eof {
        // If the next token isn't the end of file, we **must** parse a statement delimiter.
        // Otherwise, we assume one is missing and attempt to parse the next statement after
        // raising an issue.
        guard peek().isStatementDelimiter else {
          issues.append(parseFailure(.expectedStatementDelimiter, range: peek().range))
          continue
        }
      }
    }

    assert(peek().kind == .eof)

    if isMainCodeDecl {
      // Place all nodes in a `MainCodeDecl` if the parsed stream represents the main unit.
      let decl = MainCodeDecl(
        stmts: nodes,
        module: module,
        range: nodes.isEmpty
          ? peek().range
          : (nodes.first!.range.lowerBound ..< nodes.last!.range.upperBound))
      return Result(value: [decl], issues: issues)
    }

    // Check that all nodes are declarations, unless in main mode.
    var decls: [Decl] = []
    for node in nodes {
      if let decl = node as? Decl {
        decls.append(decl)
      } else {
        issues.append(parseFailure(.invalidTopLevelDeclaration(node: node), range: node.range))
      }
    }
    return Result(value: decls, issues: issues)
  }

  /// Parses a single top-level expression, statement or declaration.
  func parseTopLevelNode() -> Result<ASTNode?> {
    return DECL_KINDS.contains(peek().kind)
      ? parseDecl()
      : parseStmt()
  }

  /// Parses a comma-separated list of elements.
  ///
  /// This parser recognizes a comma-separated list of elements, optionally ending with a trailing
  /// comma, until either `delimiter` or the end of file is reached. New lines before and after
  /// each element are ignored. Parsing the list does not consume `delimiter`. In case of error
  /// while parsing an element, the method tries recover at the next separator or `delimiter`.
  ///
  /// The next token after the method returns is either `delimiter`, the semi-colon, the end of
  /// fileo r the head of an unexpected construct. It is never a new line.
  func parseCommaSeparatedList<Element>(
    delimitedBy delimiter: TokenKind,
    with parse: () -> Result<Element?>) -> Result<[Element]>
  {
    var elements: [Element] = []
    var issues: [Issue] = []

    // Parse as many elements as possible.
    while peek().kind != delimiter {
      // Skip leading new lines in front of the next element to avoid triggering an error if the
      // end of the sequence has been reached.
      consumeNewlines()
      guard (peek().kind != delimiter) && (peek().kind != .eof)
        else { break }

      // Parse the next element.
      let elementParseResult = parse()
      issues.append(contentsOf: elementParseResult.issues)
      if let element = elementParseResult.value {
        elements.append(element)
      } else {
        // If the next element couldn't be parsed, skip all input until we find either a comma, the
        // list delimiter or the end of file to recover.
        consumeMany(while: { ($0.kind != .comma) && ($0.kind != delimiter) && ($0.kind != .eof) })
      }

      consumeNewlines()
      if peek().kind != delimiter {
        // If the next token isn't the list delimiter, we **must** parse a comma. Otherwise, we
        // assume one is missing and attempt to parse the next element after raising an issue.
        guard consume(.comma) != nil else {
          issues.append(parseFailure(.expectedSeparator(separator: ","), range: peek().range))
          continue
        }
      }
    }

    assert(peek().kind != .newline)
    return Result(value: elements, issues: issues)
  }

  /// Returns the token one position ahead, without consuming the stream.
  func peek() -> Token {
    guard streamPosition < stream.count
      else { return stream.last! }
    return stream[streamPosition]
  }

  /// Returns the token after a sequence of specific tokens, without consuming it.
  func peek(afterMany skipKind: TokenKind) -> Token? {
    var peekPosition = streamPosition
    while peekPosition < stream.count {
      guard stream[peekPosition].kind == skipKind
        else { return stream[peekPosition] }
      peekPosition += 1
    }
    return nil
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
  func consume(if predicate: (Token) throws -> Bool, afterMany skipKind: TokenKind)
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

  /// Tiny helper to build parse errors.
  func parseFailure(_ syntaxError: SyntaxError, range: SourceRange) -> Issue {
    return Issue(severity: .error, message: syntaxError.description, range: range)
  }

  /// Tiny helper to build unexpected construction errors.
  func unexpectedConstruction(expected: String? = nil, got node: ASTNode) -> Issue {
    return parseFailure(.unexpectedConstruction(expected: expected, got: node), range: node.range)
  }

  /// Tiny helper to build unexpected token errors.
  func unexpectedToken(expected: String? = nil, got token: Token? = nil) -> Issue {
    let t = token ?? peek()
    return parseFailure(.unexpectedToken(expected: expected, got: t), range: t.range)
  }

  /// The infix operators' precedence groups.
  public static let precedenceGroups: [TokenKind: InfixExpr.PrecedenceGroup] = [
    .or   : InfixExpr.PrecedenceGroup(associativity: .left, precedence: 0),
    .and  : InfixExpr.PrecedenceGroup(associativity: .left, precedence: 1),
    .eq   : InfixExpr.PrecedenceGroup(associativity: .none, precedence: 2),
    .ne   : InfixExpr.PrecedenceGroup(associativity: .none, precedence: 2),
    .refeq: InfixExpr.PrecedenceGroup(associativity: .none, precedence: 2),
    .refne: InfixExpr.PrecedenceGroup(associativity: .none, precedence: 2),
    .is   : InfixExpr.PrecedenceGroup(associativity: .none, precedence: 2),
    .lt   : InfixExpr.PrecedenceGroup(associativity: .none, precedence: 3),
    .le   : InfixExpr.PrecedenceGroup(associativity: .none, precedence: 3),
    .ge   : InfixExpr.PrecedenceGroup(associativity: .none, precedence: 3),
    .gt   : InfixExpr.PrecedenceGroup(associativity: .none, precedence: 3),
    .add  : InfixExpr.PrecedenceGroup(associativity: .left, precedence: 4),
    .sub  : InfixExpr.PrecedenceGroup(associativity: .left, precedence: 4),
    .mul  : InfixExpr.PrecedenceGroup(associativity: .left, precedence: 5),
    .div  : InfixExpr.PrecedenceGroup(associativity: .left, precedence: 5),
    .mod  : InfixExpr.PrecedenceGroup(associativity: .left, precedence: 5),
  ]

}

/// The list of token kinds that denote a declaration's head.
private let DECL_KINDS: Set<TokenKind> = [
  .directive, .attribute, .static, .mutating, .let, .var, .fun, .new, .del,
  .interface, .struct, .union, .case,
]
