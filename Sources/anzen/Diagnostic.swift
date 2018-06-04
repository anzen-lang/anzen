import AST
import Utils

extension Console {

  func diagnose(range: SourceRange) {
    let source = range.start.source.read()
    let lines = source.read(lines: range.start.line)
    guard lines.count == range.start.line else { return }

    self.print(lines.last!)
    self.print(String(repeating: " ", count: range.start.column - 1) + "^")
    if (range.start.line == range.end.line) && (range.end.column - range.start.column > 1) {
      print(String(repeating: "~", count: range.end.column - range.start.column - 1))
    }
  }

}
