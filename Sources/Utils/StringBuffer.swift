public class StringBuffer: TextOutputStream, TextInputBuffer {

  public init(_ value: String = "") {
    self.value = value
  }

  public private(set) var value: String

  public func write(_ string: String) {
    value.write(string)
  }

  public func read(count: Int, from offset: Int) -> String {
    return String(value.dropFirst(offset).prefix(count))
  }

  public func read() -> String {
    return value
  }

}
