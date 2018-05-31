import AST
import Interpreter
import Parser
import Utils

protocol ExecutionError: Error {

    var range: SourceRange? { get }

}

extension ParseError: ExecutionError {}
extension RuntimeError: ExecutionError {}

func reportExecutionError<E>(_ error: E) where E: ExecutionError {
    // Report the error description.
    if let range = error.range {
        Console.err.print("\(range.start): ", in: .bold, terminator: "")
    }
    Console.err.print("error: ", in: [.bold, .red], terminator: "")
    Console.err.print(error)

    // Report the error location, if possible.
    guard let range = error.range, let source = range.file else { return }

    let lines = source.read().split(
        separator: "\n", maxSplits: range.start.line, omittingEmptySubsequences: false)
    let line = lines[range.start.line - 1].replacingOccurrences(of: "\n", with: " ")
    Console.err.print(line)
    if (range.start.line == range.end.line) && (range.end.column - range.start.column > 1) {
        Console.err.print(String(repeating: " ", count: range.start.column - 1), terminator: "")
        Console.err.print(String(repeating: "~", count: range.end.column - range.start.column))
    } else {
        Console.err.print(String(repeating: " ", count: range.start.column - 1) + "^")
    }
}
