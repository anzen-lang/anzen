#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

public struct Console: TextOutputStream {

  public init(ostream: UnsafeMutablePointer<FILE>) {
    self.ostream = ostream
  }

  public func write(_ string: String) {
    fputs("\(string)", self.ostream)
  }

  public func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    var string = items.map({ "\($0)" }).joined(separator: separator)

    if indentationLevel > 0 {
      // If the indentation level of the console is greater than 0, pad each line.
      string = string
        .split (separator: "\n")
        .map   ({ String(repeating: " ", count: indentationLevel * 2) + $0 })
        .joined(separator: "\n")
    }

    self.write(string + terminator)
  }

  public mutating func indent() {
    indentationLevel += 1
  }

  public mutating func dedent() {
    precondition(indentationLevel > 0)
    indentationLevel -= 1
  }

  public static var out: Console {
    return Console(ostream: stdout)
  }

  public static var err: Console {
    return Console(ostream: stderr)
  }

  let ostream: UnsafeMutablePointer<FILE>

  var indentationLevel: Int = 0

}

public protocol DebugRepresentable {

  func printDebugRepresentation(in console: Console)

}
