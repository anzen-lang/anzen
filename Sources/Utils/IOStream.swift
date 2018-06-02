#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

public protocol TextInputStream {

  /// Reads and returns at most `count` characters from the stream as a single string.
  ///
  /// If `count` is `nil`, reads until the end of the stream.
  func read(characters count: Int?) -> String

}

extension TextInputStream {

  /// Reads and returns the characters until the end of the stream.
  public func read() -> String {
    return read(characters: nil)
  }

  /// Reads and returns at most `count` lines from the stream.
  public func read(lines count: Int) -> [String] {
    var lines: [String] = []
    var line = ""
    while lines.count < count {
      let char = read(characters: 1)
      if char == "" {
        lines.append(line)
        break
      }
      if char == "\n" {
        lines.append(line)
        line = ""
      } else {
        line.append(char)
      }
    }
    return lines
  }

}

public class TextFileStream: TextInputStream, TextOutputStream {

  public init(filename: String) {
    self.filename = filename
  }

  /// A string representing the name of the file to open.
  public let filename: String
  /// The offset from which read the stream.
  private var offset: Int = 0

  /// The basename of the file.
  public var basename: String {
    return filename.split(separator: "/").last.map(String.init) ?? ""
  }

  /// Reads and returns at most `count` characters from the stream as a single string.
  ///
  /// If `count` is `nil`, reads until EOF.
  public func read(characters count: Int?) -> String {
    guard let pointer = fopen(filename, "r") else { return "" }
    defer { fclose(pointer) }
    fseek(pointer, offset, SEEK_SET)

    setlocale(LC_ALL, "")
    var buffer: [wint_t] = []
    while (count == nil) || buffer.count < count! {
      let char = fgetwc(pointer)
      guard char != WEOF else { break }
      buffer.append(char)
    }

    let result = String(buffer.map({ Character(Unicode.Scalar(UInt32($0))!) }))
    result.withCString { offset += strlen($0) }
    return result
  }

  /// Reads and returns the characters from the stream until EOF.
  public func read() -> String {
    guard let pointer = fopen(filename, "r") else { return "" }
    defer { fclose(pointer) }
    fseek(pointer, 0, SEEK_END)
    let size = ftell(pointer)
    fseek(pointer, offset, SEEK_SET)

    let buffer = [CChar](repeating: 0, count: size - offset + 1)
    fread(UnsafeMutablePointer(mutating: buffer), MemoryLayout<CChar>.size, size - offset, pointer)
    offset = size
    return String(cString: buffer)
  }

  public func rewind() {
    offset = 0
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
    body: (TextFileStream) throws -> Result) rethrows -> Result
  {
    let template = String(cString: getenv("TMPDIR")) + prefix + "XXXXXX"
    var buffer = template.utf8CString
    _ = buffer.withUnsafeMutableBufferPointer {
      return mkstemp($0.baseAddress)
    }
    let path = String(cString: buffer.withUnsafeBufferPointer { $0.baseAddress! })
    defer { remove(path) }
    return try body(TextFileStream(filename: path))
  }

}

extension String: TextInputStream {

  public func read(characters count: Int?) -> String {
    return count != nil
      ? String(prefix(count!))
      : self
  }

}
