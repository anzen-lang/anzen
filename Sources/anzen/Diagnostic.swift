import AST
import Sema
import Utils
import SystemKit

extension Console {

  func diagnose(range: SourceRange) {
    let lines = try! range.start.source.read(lines: range.start.line)
    guard lines.count == range.start.line else { return }

    self.print(lines.last!)

    self.print(String(repeating: " ", count: range.start.column - 1), terminator: "")
    self.print("^".styled("green"), terminator: "")
    if (range.start.line == range.end.line) && (range.end.column - range.start.column > 1) {
      let length = range.end.column - range.start.column - 1
      self.print(String(repeating: "~", count: length).styled("green"))
    } else {
      self.print()
    }
  }

  func diagnose(error: ASTError) {
    // Output the heading of the error.
    let range = error.node.range
    let filename: String
    if let path = (range.start.source as? TextFile)?.path {
      filename = path.relative(to: .workingDirectory).pathname
    } else {
      filename = "<unknown>"
    }
    let title = try! StyledString(
      "{\(filename)::\(range.start.line)::\(range.start.column):::bold} {error:::bold,red}")

    // Diagnose the cause of the error.
    switch error.cause {
    case let semaError as SAError:
      // Type inference errors should receive more care, so as to produce a better diagnostic.
      if case .unsolvableConstraint(let constraint, let cause) = semaError {
        if case .disjunction = constraint.kind {
          for choice in constraint.choices {
            System.err.print(title, terminator: " ")
            diagnoseSolvingFailure(constraint: choice, cause: cause)
          }
        } else {
          System.err.print(title, terminator: " ")
          diagnoseSolvingFailure(constraint: constraint, cause: cause)
        }
      } else {
        System.err.print(title, terminator: " ")
        System.err.print(semaError)
        System.err.diagnose(range: range)
      }

    default:
      System.err.print(error.cause)
      System.err.diagnose(range: range)
    }
  }

  func diagnoseSolvingFailure(constraint: Constraint, cause: SolverResult.FailureKind) {
    assert(constraint.kind != .disjunction)
    assert(!constraint.location.paths.isEmpty)

    switch constraint.location.paths.last! {
    case .rvalue:
      // An "r-value" location describes a constraint that failed because the r-value of a binding
      // statement isn't compatible with the l-value.
      let (t, u) = constraint.types!
      System.err.print("cannot assign to type '\(u)' value of type '\(t)'".styled("bold"))

    default:
      constraint.prettyPrint(in: System.err)
    }

    System.err.diagnose(range: constraint.location.resolved.range)
  }

}
