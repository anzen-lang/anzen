import XCTest

import AST
@testable import Parser

protocol ParserTestCase {

  func getParser(for source: String) -> Parser
  func parse<T>(_ source: String, with parse: (Parser) -> () -> Parser.Result<T>)
    -> Parser.Result<T>

}

extension ParserTestCase {

  func getParser(for input: String) -> Parser {
    let module = Module(id: "<test>")
    let parser = try? Parser(source: SourceRef(name: "<test>", buffer: input), module: module)
    XCTAssertNotNil(parser)
    return parser!
  }

  func parse<T>(_ source: String, with parse: (Parser) -> () -> Parser.Result<T>)
    -> Parser.Result<T>
  {
    return parse(getParser(for: source))()
  }

}
