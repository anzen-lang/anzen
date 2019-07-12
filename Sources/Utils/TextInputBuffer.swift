import SystemKit

/// A type that can be the target of text reading operations.
///
/// A text input buffer is an object that has methods to read one or several characters as strings
/// from some buffer of characters.
public protocol TextInputBuffer {

  /// Reads `count` characters starting from `offet`.
  func read(count: Int, from offset: Int) throws -> String

  /// Reads all characters of the buffer.
  func read() throws -> String

}

extension TextInputBuffer {

  /// Reads up to `count` lines of the buffer.
  public func read(lines count: Int) throws -> [String] {
    return try read().split(separator: "\n", omittingEmptySubsequences: false)
      .prefix(count)
      .map({ String($0) })
  }

}

extension TextFile: TextInputBuffer {
}

extension String: TextInputBuffer {

  public func read(count: Int, from offset: Int) -> String {
    return String(self.dropFirst(offset).prefix(count))
  }

  public func read() -> String {
    return self
  }

}
