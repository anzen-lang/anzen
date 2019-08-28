import XCTest

@testable import AST
@testable import Parser

protocol ParserTestCase {

  typealias ParseResult<T> = (value: T, issues: [Issue])

  func getParser(for source: String) -> Parser
  func parse<T>(_ source: String, with parse: (Parser) -> (inout [Issue]) -> T) -> ParseResult<T>

}

extension ParserTestCase {

  func getParser(for input: String) -> Parser {
    let module = Module(id: "<test>", generationNumber: 0)
    let parser = try? Parser(source: SourceRef(name: "<test>", buffer: input), module: module)
    XCTAssertNotNil(parser)
    return parser!
  }

  func parse<T>(_ source: String, with parse: (Parser) -> (inout [Issue]) -> T) -> ParseResult<T> {
    var issues: [Issue] = []
    return (parse(getParser(for: source))(&issues), issues)
  }

}
