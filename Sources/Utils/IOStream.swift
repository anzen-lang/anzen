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

public struct TextFile: TextInputBuffer, TextOutputStream {

  public init(filename: String) {
    self.filename = filename
  }

  /// A string representing the name of the file to open.
  public let filename: String

  /// The basename of the file.
  public var basename: String {
    return filename.split(separator: "/").last.map(String.init) ?? ""
  }

  /// Reads and return at most `count` characters from the buffer, offset by `offset`.
  public func read(count: Int, from offset: Int) -> String {
    guard let pointer = fopen(filename, "r") else { return "" }
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
    guard let pointer = fopen(filename, "a") else { return }
    defer { fclose(pointer) }
    _ = string.withCString { fwrite($0, MemoryLayout<CChar>.size, strlen($0), pointer) }
  }

  public static func exists(filename: String) -> Bool {
    return access(filename, F_OK) != -1
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
    let path = String(cString: buffer.withUnsafeBufferPointer { $0.baseAddress! })
    defer { remove(path) }
    return try body(TextFile(filename: path))
  }

}

extension String: TextInputBuffer {

  public func read(count: Int, from offset: Int) -> String {
    return String(dropFirst(offset).prefix(count))
  }

}
