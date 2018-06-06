import Utils

public struct SourceLocation {

  public init(source: TextInputBuffer, line: Int = 1, column: Int = 1, offset: Int = 0) {
    self.source = source
    self.line = line
    self.column = column
    self.offset = offset
  }

  /// The source in which the location refers to.
  public let source: TextInputBuffer
  /// The 1-indexed line number in the source text of the location.
  public var line: Int
  /// The column number in the source text of the location.
  public var column: Int
  /// The character offset in the source text of the location.
  public var offset: Int

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

  public init(from start: SourceLocation, to end: SourceLocation) {
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
