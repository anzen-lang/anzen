import Utils
import SystemKit

/// A pointer to an text input buffer.
public class SourceRef {

  /// The name of the source.
  public let name: String
  /// The text input buffer.
  public let buffer: TextInputBuffer

  public init(name: String, buffer: TextInputBuffer) {
    self.name = name
    self.buffer = buffer
  }

}

/// A location in a text input buffer, given as two 1-based line and column indices.
public struct SourceLocation {

  /// The source in which the location refers to.
  public let sourceRef: SourceRef
  /// The 1-indexed line number in the source text of the location.
  public var line: Int
  /// The column number in the source text of the location.
  public var column: Int
  /// The character offset in the source text of the location.
  public var offset: Int

  public init(sourceRef: SourceRef, line: Int = 1, column: Int = 1, offset: Int = 0) {
    self.sourceRef = sourceRef
    self.line = line
    self.column = column
    self.offset = offset
  }

  public func advancedBy(columns count: Int) -> SourceLocation {
    return SourceLocation(
      sourceRef: sourceRef,
      line: line,
      column: column + count,
      offset: offset + count)
  }

}

extension SourceLocation: Hashable {

  public static func == (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
    return lhs.sourceRef === rhs.sourceRef
        && lhs.offset == rhs.offset
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(sourceRef))
    hasher.combine(offset)
  }

}

extension SourceLocation: Comparable {

  public static func < (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
    return lhs.offset < rhs.offset
  }

}

extension SourceLocation: CustomStringConvertible {

  public var description: String {
    return "\(line):\(column)"
  }

}

public typealias SourceRange = Range<SourceLocation>

extension SourceRange {

  public var sourceRef: SourceRef {
    return lowerBound.sourceRef
  }

}
