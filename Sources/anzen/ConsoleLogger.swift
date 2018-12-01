import AnzenLib
import AST
import Dispatch
import Parser
import Sema
import SystemKit
import Utils

public struct ConsoleLogger: Logger {

  public init(console: Console = System.err, useStyles: Bool = true) {
    self.console = console
    self.isUsingStyles = useStyles
  }

  public let console: Console
  public let isUsingStyles: Bool

  private var messages: [String] = []
  private let messageQueue = DispatchQueue(label: "messageQueue")

  public func log(_ text: String) {
    DispatchQueue.global(qos: .utility).async {
      self.messageQueue.sync {
        self.console.write(text)
      }
    }
  }

  public func error(_ err: Error) {
    switch err {
    case let parseError as ParseError:
      log(describe(parseError))

    default:
      if isUsingStyles {
        log("error:".styled("bold,red") + " \(error)\n")
      } else {
        log("error: \(err)\n")
      }
    }
  }

  public func describe(_ err: ParseError) -> String {
    let range = err.range
    let filename = ((range.start.source as? TextFile)?.path).map {
      $0.relative(to: .workingDirectory).pathname
    } ?? "<unknown>"

    let heading: String
    if isUsingStyles {
      heading = "\(filename)::\(range.start.line)::\(range.start.column): ".styled("bold") +
                "error: ".styled("bold,red") +
                "\(err.cause)\n"
    } else {
      heading = "\(filename)::\(range.start.line)::\(range.start.column): error: \(err.cause)\n"
    }

    return heading + describe(range)
  }

  public func describe(_ err: ASTError) -> String {
    let range = err.node.range
    let filename = ((range.start.source as? TextFile)?.path).map {
      $0.relative(to: .workingDirectory).pathname
    } ?? "<unknown>"

    var heading: String
    if isUsingStyles {
      heading = "\(filename)::\(range.start.line)::\(range.start.column): ".styled("bold") +
                "error:".styled("bold,red")
    } else {
      heading = "\(filename)::\(range.start.line)::\(range.start.column): error: "
    }

    switch err.cause {
    case let semaError as SAError:
      heading += "\(semaError)\n"
    default:
      heading += "\(err.cause)\n"
    }

    return heading + describe(range)
  }

  public func describe<S>(_ errs: S) -> String where S: Sequence, S.Element == ASTError {
    return errs.sorted(by: <).map(describe).joined()
  }

  /// Logs the given type solver error.
  public func describe(
    unsolvableConstraint constraint: Constraint,
    causedBy cause: SolverResult.FailureKind) -> String
  {
    return isUsingStyles
      ? "error: ".styled("bold,red") + "type error\n"
      : "error: type error\n"
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

    if isUsingStyles {
      cursor = cursor.styled("green")
    }

    return snippet + leading + cursor
  }

}
