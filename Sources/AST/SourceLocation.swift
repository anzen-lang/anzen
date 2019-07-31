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

}

extension SourceLocation: Comparable {

  public static func == (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
    return lhs.offset == rhs.offset
  }

  public static func < (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
    return lhs.offset < rhs.offset
  }

}

extension SourceLocation: CustomStringConvertible {

  public var description: String {
    return "\(line):\(column)"
  }

}

public struct SourceRange: RangeExpression {

  /// The source in which the range refers to.
  public var sourceRef: SourceRef {
    return start.sourceRef
  }

  public init(from start: SourceLocation, to end: SourceLocation) {
    assert(start.sourceRef === end.sourceRef)
    self.start = start
    self.end = end
  }

  public init(at location: SourceLocation) {
    self.start = location
    self.end = location
  }

  public func relative<C>(to collection: C) -> Range<SourceLocation>
    where C: Collection, C.Index == SourceLocation
  {
    return Range.init(uncheckedBounds: (lower: start, upper: end))
  }

  public func contains(_ element: SourceLocation) -> Bool {
    return element >= start && element <= end
  }

  public var length: Int {
    return end.offset - start.offset
  }

  public let start: SourceLocation
  public let end: SourceLocation

}

extension SourceRange: Equatable {

  public static func == (lhs: SourceRange, rhs: SourceRange) -> Bool {
    return lhs.start == rhs.start && lhs.end == rhs.end
  }

}

extension SourceRange: CustomStringConvertible {

  public var description: String {
    return "\(start) ... \(end)"
  }

}
