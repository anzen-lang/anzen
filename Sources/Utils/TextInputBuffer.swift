import SystemKit

public protocol TextInputBuffer {

  func read(count: Int, from offset: Int) throws -> String
  func read() throws -> String

}

extension TextInputBuffer {

  public func read(lines: Int) throws -> [String] {
    return try read().split(separator: "\n")
      .prefix(lines)
      .map({ String($0) })
  }

}

extension TextFile: TextInputBuffer {
}

extension String: TextInputBuffer {

  public func read(count: Int, from offset: Int) -> String {
    return String(self.dropFirst(offset).prefix(count))
  }

  public func read() -> String {
    return self
  }

}
