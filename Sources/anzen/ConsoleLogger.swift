import AnzenLib
import AST
import Dispatch
import Parser
import Sema
import SystemKit
import Utils

public struct ConsoleLogger: Logger {

  public init(console: Console = System.err) {
    self.console = console
  }

  public let console: Console

  private var messages: [String] = []
  private let messageQueue = DispatchQueue(label: "messageQueue")

  public func log(_ text: String) {
    messageQueue.sync { self.console.write(text) }
  }

  public func error(_ err: Error) {
    switch err {
    case let parseError as ParseError:
      log(describe(parseError))
    default:
      log("error:".styled("bold,red") + " \(error)\n")
    }
  }

  public func describe(_ err: ParseError) -> String {
    let range = err.range
    let filename = ((range.start.source as? TextFile)?.path).map {
      $0.relative(to: .workingDirectory).pathname
    } ?? "<unknown>"

    let heading = "\(filename)::\(range.start.line)::\(range.start.column): ".styled("bold") +
                  "error: ".styled("bold,red") +
                  "\(err.cause)\n"

    return heading + describe(range)
  }

  public func describe(_ err: ASTError) -> String {
    let range = err.node.range
    let filename = ((range.start.source as? TextFile)?.path).map {
      $0.relative(to: .workingDirectory).pathname
    } ?? "<unknown>"

    var heading = "\(filename)::\(range.start.line)::\(range.start.column): ".styled("bold") +
                  "error:".styled("bold,red")

    switch err.cause {
    case let semaError as SAError:
      heading += "\(semaError)\n"
    default:
      heading += "\(err.cause)\n"
    }

    return heading + describe(range)
  }

  /// Logs the given type solver error.
  public func describe(_ err: SolverFailure) -> String {
    return "error: ".styled("bold,red") + "type error\n"
  }

  public func describe(_ range: SourceRange) -> String {
    guard let lines = try? range.start.source.read(lines: range.start.line)
      else { return "" }
    guard lines.count == range.start.line
      else { return "" }

    let snippet = lines.last! + "\n"
    let leading = String(repeating: " ", count: range.start.column - 1)

    var cursor = "^"
    if (range.start.line == range.end.line) && (range.end.column - range.start.column > 1) {
      let length = range.end.column - range.start.column - 1
      cursor += String(repeating: "~", count: length) + "\n"
    } else {
      cursor += "\n"
    }

    return snippet + leading + cursor.styled("red")
  }

}
