import XCTest

@testable import Parser

protocol ParserTestCase {

  func getParser(for source: String) -> Parser
  func parse<T>(_ source: String, with parse: (Parser) -> () -> Parser.Result<T>)
    -> Parser.Result<T>

}

extension ParserTestCase {

  func getParser(for source: String) -> Parser {
    let parser = try? Parser(source: source)
    XCTAssertNotNil(parser)
    return parser!
  }

  func parse<T>(_ source: String, with parse: (Parser) -> () -> Parser.Result<T>)
    -> Parser.Result<T>
  {
    return parse(getParser(for: source))()
  }

}
