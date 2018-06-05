#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

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
