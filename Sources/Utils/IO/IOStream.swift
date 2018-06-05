#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

public protocol TextInputStream {

  /// Reads and returns at most `count` characters from the stream.
  mutating func read(count: Int) -> String

}

extension TextInputStream {

  /// Reads and returns all characters until the end of the stream.
  public mutating func read() -> String {
    var result: String = ""
    while true {
      let buffer = read(count: 1024)
      guard !buffer.isEmpty else { return result }
      result += buffer
    }
  }

  /// Reads and returns at most `count` lines from the stream.
  public mutating func read(lines count: Int) -> [String] {
    var lines: [String] = []
    var line = ""
    while lines.count < count {
      let char = read(count: 1)
      if char == "" {
        lines.append(line)
        break
      } else if char == "\n" {
        lines.append(line)
        line = ""
      } else {
        line.append(char)
      }
    }
    return lines
  }

}

public protocol TextInputBuffer {

  /// Reads and return at most `count` characters from the buffer, offset by `offset`.
  func read(count: Int, from offset: Int) -> String

}

extension TextInputBuffer {

  /// Reads and return all characters from the buffer, offset by `offset`.
  public func read(from offset: Int) -> String {
    return read(count: Int.max - offset, from: offset)
  }

  /// Reads and return at most `count` characters from the buffer.
  func read(count: Int) -> String {
    return read(count: count, from: 0)
  }

  /// Reads and returns all characters from the buffer.
  public func read() -> String {
    return read(count: Int.max, from: 0)
  }

  /// Reads and returns at most `count` lines from the buffer.
  public func read(lines count: Int) -> [String] {
    return read()
      .split(separator: "\n", maxSplits: count + 1, omittingEmptySubsequences: false)
      .prefix(count)
      .map({ String($0) })
  }

}

public struct Path {

  public init(url: String) {
    let urlComponents = url.split(separator: "/").map({ String($0) })
    self.components = url.starts(with: "/")
      ? urlComponents
      : Path.currentWorkingDirectory.components + urlComponents
  }

  public init<S>(components: S) where S: Sequence, S.Element == String {
    self.components = Array(components)
  }

  /// The path components.
  private let components: [String]

  /// The string representation of the path.
  public var url: String {
    return "/" + components.joined(separator: "/")
  }

  /// The basename of the path.
  public var basename: String {
    return components.last ?? ""
  }

  /// Whether or not the path is an existing file.
  public var isFile: Bool {
    return access(url, F_OK) != -1
  }

  public func appending(_ components: String) -> Path {
    let other = components.split(separator: "/").map({ String($0) })
    return Path(components: self.components + other)
  }

  public func pathname(relativeTo other: Path) -> String {
    var i = 0
    while i < Swift.min(self.count, other.count) {
      guard self[i] == other[i] else { break }
      i += 1
    }
    return ([String](repeating: "..", count: other.count - i) + components.dropFirst(i))
      .joined(separator: "/")
  }

  public static var currentWorkingDirectory: Path {
    let cwd = getcwd(UnsafeMutablePointer(bitPattern: 0), 0)
    defer { cwd?.deallocate() }
    return cwd != nil
      ? Path(url: String(cString: cwd!))
      : Path(components: [])
  }

}

extension Path: BidirectionalCollection {

  public typealias Index = Int
  public typealias Element = String

  public var startIndex: Index { return components.startIndex }
  public var endIndex: Index { return components.endIndex }

  public func index(after i: Index) -> Index {
    return i + 1
  }

  public func index(before i: Index) -> Index {
    return i - 1
  }

  public subscript(position: Index) -> Element {
    return components[position]
  }

}

extension Path: Equatable {

  public static func == (lhs: Path, rhs: Path) -> Bool {
    return lhs.components == rhs.components
  }

}

extension Path: ExpressibleByStringLiteral {

  public init(stringLiteral value: String) {
    self.init(url: value)
  }

}

extension Path: CustomStringConvertible {

  public var description: String {
    return url
  }

}

public struct TextFile: TextInputBuffer, TextOutputStream {

  public init(filepath: Path) {
    self.filepath = filepath
  }

  /// A string representing the path of the file to open.
  public let filepath: Path

  /// Reads and return at most `count` characters from the buffer, offset by `offset`.
  public func read(count: Int, from offset: Int) -> String {
    guard let pointer = fopen(filepath.url, "r") else { return "" }
    defer { fclose(pointer) }

    setlocale(LC_ALL, "")
    var buffer: [wint_t] = []
    while buffer.count < (count + offset) {
      let char = fgetwc(pointer)
      guard char != WEOF else { break }
      buffer.append(char)
    }

    return String(buffer.dropFirst(offset).map({ Character(Unicode.Scalar(UInt32($0))!) }))
  }

  /// Appends the given string to the stream.
  public func write(_ string: String) {
    guard let pointer = fopen(filepath.url, "a") else { return }
    defer { fclose(pointer) }
    _ = string.withCString { fwrite($0, MemoryLayout<CChar>.size, strlen($0), pointer) }
  }

  public static func withTemporary<Result>(
    prefix: String = "org.anzen-lang.",
    body: (TextFile) throws -> Result) rethrows -> Result
  {
    let template = String(cString: getenv("TMPDIR")) + prefix + "XXXXXX"
    var buffer = template.utf8CString
    _ = buffer.withUnsafeMutableBufferPointer {
      return mkstemp($0.baseAddress)
    }
    let url = String(cString: buffer.withUnsafeBufferPointer { $0.baseAddress! })
    defer { remove(url) }
    return try body(TextFile(filepath: Path(url: url)))
  }

}

extension String: TextInputBuffer {

  public func read(count: Int, from offset: Int) -> String {
    return String(dropFirst(offset).prefix(count))
  }

}
