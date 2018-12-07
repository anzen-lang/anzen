public struct RuntimeError: Error {

  public init(_ message: String) {
    self.message = message
  }

  public let message: String

}
