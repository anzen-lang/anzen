import AST
import SystemKit
import Utils

public protocol IssueReporter {

  /// Reports the given issue.
  func report(_ issue: Issue)

}

/// An implementation of an issue reporter that writes them on `stderr`.
public struct ConsoleIssueReporter: IssueReporter {

  public func report(_ issue: Issue) {
    System.err.write(heading(issue))
    System.err.write(excerpt(issue.range))
  }

  /// Returns the header of a report for the given issue.
  public func heading(_ issue: Issue) -> String {
    let source = issue.range.lowerBound.sourceRef.name
    let start = "\(issue.range.lowerBound.line):\(issue.range.lowerBound.column)"
    let location = "\(source):\(start): "

    let issueKind = issue.severity == .error
      ? "error:".styled("bold,red")
      : "warning:".styled("bold,yellow")
    return "\(location)\(issueKind) \(issue.message)\n"
  }

  /// Returns an excerpt of the source at the given location.
  public func excerpt(_ range: SourceRange) -> String {
    let start = range.lowerBound
    let end = range.upperBound

    guard let lines = try? start.sourceRef.buffer.read(lines: range.lowerBound.line)
      else { return "" }
    guard lines.count == start.line
      else { return "" }

    let line = lines.last! + "\n"
    let leading = String(repeating: " ", count: start.column - 1)

    var cursor = ""
    if (start.line == end.line) && (end.column - start.column > 1) {
      let length = end.column - start.column
      cursor += String(repeating: "~", count: length) + "\n"
    } else {
      cursor += "^\n"
    }

    return line + leading + cursor.styled("green")
  }

}
