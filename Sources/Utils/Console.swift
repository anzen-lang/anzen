#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

public struct Console: TextOutputStream {

  public init(ostream: UnsafeMutablePointer<FILE>) {
    self.ostream = ostream
  }

  public struct Style: CustomStringConvertible, ExpressibleByArrayLiteral {

    public init(_ attributes: Set<Int32>) {
      self.attributes = attributes
    }

    public init(arrayLiteral: Style...) {
      self.attributes = Set(arrayLiteral.reduce(Set<Int32>(), { $0.union($1.attributes) }))
    }

    public var description: String {
      guard !self.attributes.isEmpty else { return "" }
      let attrs = self.attributes.map({ "\($0)" }).joined(separator: ";")
      return "\u{001B}[\(attrs)m"
    }

    public static let reset         = Style([0])
    public static let bold          = Style([1])
    public static let dimmed        = Style([2])
    public static let italic        = Style([3])
    public static let underline     = Style([4])
    public static let strikethrough = Style([9])
    public static let black         = Style([30])
    public static let red           = Style([31])
    public static let green         = Style([32])
    public static let yellow        = Style([33])
    public static let blue          = Style([34])
    public static let magenta       = Style([35])
    public static let cyan          = Style([36])
    public static let white         = Style([37])
    public static let `default`     = Style([38])

    let attributes: Set<Int32>

  }

  public func write(_ string: String) {
    fputs("\(string)", self.ostream)
  }

  public func print(
    _ items: Any..., in style: Style = .default,
    separator: String = " ", terminator: String = "\n")
  {
    let string = Console.isTerminalSupported
      ? items.map({ "\(style)\($0)\(Style.reset)" })
      : items.map({ "\($0)" })
    self.write(string.joined(separator: separator) + terminator)
  }

  public static var out: Console {
    return Console(ostream: stdout)
  }

  public static var err: Console {
    return Console(ostream: stderr)
  }

  let ostream: UnsafeMutablePointer<FILE>

  static var isTerminalSupported: Bool {
    guard let capabilities = getenv("TERM") else { return false }
    return (String(cString: capabilities).lowercased() != "dumb") && (isatty(fileno(stdout)) != 0)
  }

}

public protocol DebugRepresentable {

  func printDebugRepresentation(in console: Console)

}
