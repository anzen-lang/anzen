import Utils

public struct SourceLocation {

  public init(file: File? = nil, line: Int = 1, column: Int = 1, offset: Int = 0) {
    self.file = file
    self.line = line
    self.column = column
    self.offset = offset
  }

  public let file: File?
  public var line: Int
  public var column: Int
  public var offset: Int

}

extension SourceLocation: Comparable {

  public static func == (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
    return lhs.file == rhs.file && lhs.offset == rhs.offset
  }

  public static func < (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
    precondition(lhs.file == rhs.file, "cannot compare location accress different files")
    return lhs.offset < rhs.offset
  }

}

extension SourceLocation: CustomStringConvertible {

  public var description: String {
    return "\(file?.basename ?? ""):\(line):\(column)"
  }

}

public struct SourceRange: RangeExpression {

  public init(from start: SourceLocation, to end: SourceLocation) {
    precondition(start.file == end.file, "must contain locations from the same file")
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

  public var file: File? {
    return start.file
  }

  public var content: Substring? {
    guard let fileContent = start.file?.read() else { return nil }
    let startIndex = fileContent.index(fileContent.startIndex, offsetBy: start.offset)
    let endIndex = fileContent.index(fileContent.startIndex, offsetBy: end.offset)
    return fileContent[startIndex ... endIndex]
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

  public var preview: String? {
    guard let source = file else { return nil }
    var result = ""

    let lines = source.read().split(
      separator: "\n", maxSplits: start.line, omittingEmptySubsequences: false)
    result += lines[start.line - 1] + "\n"

    result += String(repeating: " ", count: start.column - 1) + "^"
    if (start.line == end.line) && (end.column - start.column > 1) {
      result += String(repeating: "~", count: end.column - start.column - 1)
    }

    return result
  }

  public var description: String {
    return "\(start) ... \(end)"
  }

}
