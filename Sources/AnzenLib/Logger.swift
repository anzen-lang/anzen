import AST
import Parser
import Sema
import SystemKit
import Utils

public protocol Logger {

  /// Logs the given text, only if the logger's verbosity is higher than `verbose`.
  func verbose(_ text: @autoclosure () -> String)

  /// Logs the given text, only if the logger's verbosity is higher than `debug`.
  func debug(_ text: @autoclosure () -> String)

  /// Writes the given text.
  func write(_ text: String)

  /// Logs an error.
  func log(error: Error)

  /// Logs the given parse error.
  func log(parseError: ParseError)

  /// Logs the given AST error.
  func log(astError: ASTError)

  /// Logs the given type solver error.
  func log(unsolvableConstraint constraint: Constraint, causedBy cause: SolverResult.FailureKind)

  /// Logs a source range.
  func log(range: SourceRange)

}

extension Logger {

  /// Logs an error.
  public func log(error: Error) {
    switch error {
    case let parseError as ParseError:
      log(error: parseError)

    default:
      write("error:".styled("bold,red") + " \(error)\n")
    }
  }

  /// Logs the given parse error.
  public func log(parseError: ParseError) {
    // Logs the error heading.
    let range = parseError.range
    let filename = ((range.start.source as? TextFile)?.path).map {
      $0.relative(to: .workingDirectory).pathname
    } ?? "<unknown>"
    write(
      "\(filename)::\(range.start.line)::\(range.start.column): ".styled("bold") +
      "error: ".styled("bold,red") +
      "\(parseError.cause)\n")

    // Log the code snippet.
    log(range: range)
  }

  /// Logs the given AST error.
  public func log(astError: ASTError) {
    // Logs the error heading.
    let range = astError.node.range
    let filename = ((range.start.source as? TextFile)?.path).map {
      $0.relative(to: .workingDirectory).pathname
    } ?? "<unknown>"
    write(
      "\(filename)::\(range.start.line)::\(range.start.column): ".styled("bold") +
      "error:".styled("bold,red"))

    // Diagnose the cause of the error.
    switch astError.cause {
    case let semaError as SAError:
      write("\(semaError)\n")
    default:
      write("\(astError.cause)\n")
    }

    // Log the code snippet.
    log(range: range)
  }

  /// Logs the given AST errors.
  public func log<S>(astErrors: S) where S: Sequence, S.Element == ASTError {
    for error in astErrors.sorted(by: <) {
      log(astError: error)
    }
  }

  /// Logs the given type solver error.
  public func log(unsolvableConstraint constraint: Constraint, causedBy cause: SolverResult.FailureKind) {
    write("error: ".styled("bold,red") + "type error\n")
  }

  /// Logs a source range.
  public func log(range: SourceRange) {
    guard let lines = try? range.start.source.read(lines: range.start.line)
      else { return }
    guard lines.count == range.start.line
      else { return }

    write(lines.last! + "\n")
    write(String(repeating: " ", count: range.start.column - 1))
    write("^".styled("green"))
    if (range.start.line == range.end.line) && (range.end.column - range.start.column > 1) {
      let length = range.end.column - range.start.column - 1
      write(String(repeating: "~", count: length).styled("green") + "\n")
    } else {
      write("\n")
    }
  }

}

/// An enumeration of the verbosity levels of the logger.
public enum Verbosity: Int, Comparable {

  /// Outputs errors only.
  case normal = 0
  /// Outputs various debug regarding the loading process of a module.
  case verbose
  /// Outputs all debug information, including the typing constraints of the semantic analysis.
  case debug

  public static func < (lhs: Verbosity, rhs: Verbosity) -> Bool {
    return lhs.rawValue < rhs.rawValue
  }

}
