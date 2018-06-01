#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

public enum IOError: Error {

  case fileNotFound(path: String) // ENOENT (2)
  case permissionDenied           // EACCES (13)
  case readOnly                   // EROFS  (30)
  case other(errno: Int32)

  public var number: Int32 {
    switch self {
    case .fileNotFound:         return ENOENT
    case .permissionDenied:     return EACCES
    case .readOnly:             return EROFS
    case .other(errno: let no): return no
    }
  }

  public static func == (lhs: IOError, rhs: Int32) -> Bool {
    return lhs.number == rhs
  }

}

public class File {

  public enum Mode: String {
    case read      = "r"
    case write     = "w"
    case readWrite = "rw"
  }

  public init(path: String, mode: Mode = .read) throws {
    self.path = path
    self.openMode = mode
    self.fp = fopen(path, mode.rawValue)
    if self.fp == nil {
      switch errno {
      case ENOENT: throw IOError.fileNotFound(path: path)
      case EACCES: throw IOError.permissionDenied
      case EROFS : throw IOError.readOnly
      default    : throw IOError.other(errno: errno)
      }
    }
  }

  deinit {
    if fp != nil { fclose(fp) }
  }

  public func read() -> String {
    guard size > 0 else { return "" }

    let buffer = [CChar](repeating: 0, count: size + 1)
    fread(UnsafeMutablePointer(mutating: buffer), MemoryLayout<CChar>.size, size, fp)
    rewind(fp)
    return String(cString: buffer)
  }

  @discardableResult
  public func write(data: String) -> Bool {
    let cString = Array(data.utf8)
    return fwrite(cString, cString.count, 1, fp) == 1
  }

  public lazy var size: Int = {
    fseek(fp, 0, SEEK_END)
    defer { rewind(fp) }
    return ftell(fp)
  }()

  public var basename: String {
    return path.split(separator: "/").last.map(String.init) ?? ""
  }

  public let path: String
  public let openMode: Mode

  private let fp: UnsafeMutablePointer<FILE>?

  public static func exists(path: String) -> Bool {
    return access(path, F_OK) != -1
  }

}

extension File: Equatable {

  public static func == (lhs: File, rhs: File) -> Bool {
    return lhs.path == rhs.path
  }

}
