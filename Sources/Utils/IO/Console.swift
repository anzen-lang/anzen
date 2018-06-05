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
    let string = items.map({ "\($0)" }).joined(separator: separator)
    self.write(string + terminator)
  }

  public static var out: Console {
    return Console(ostream: stdout)
  }

  public static var err: Console {
    return Console(ostream: stderr)
  }

  let ostream: UnsafeMutablePointer<FILE>

}

public protocol DebugRepresentable {

  func printDebugRepresentation(in console: Console)

}
