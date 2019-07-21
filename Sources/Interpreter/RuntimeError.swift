import AST

/// A runtime error.
public protocol RuntimeError: Error {

  /// The details of the runtime error.
  var message: String { get }
  /// The range in the Anzen source corresponding to this instruction.
  var range: SourceRange? { get }

}

/// A memory error.
public struct MemoryError: Error {

  public let message: String
  public let range: SourceRange?

  init(_ message: String, at range: SourceRange? = nil) {
    self.message = message
    self.range = range
  }

}
