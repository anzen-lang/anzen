public protocol Logger {

  /// Logs a message.
  func log(_ text: String)

  /// Logs fine-grained messages usually aimed at debugging the compiler.
  func debug(_ text: String)

  /// Logs warnings messages about potentially harmful events.
  func warning(_ text: String)

  /// Logs error messages about events that caused the compiler to stop.
  func error(_ text: String)

  /// Logs error messages about events that caused the compiler to stop.
  func error(_ err: Error)

}

extension Logger {

  public func debug(_ text: String) {
    log(text)
  }

  public func warning(_ text: String) {
    log(text)
  }

  public func error(_ text: String) {
    log(text)
  }

  public func error(_ err: Error) {
    error("\(err)")
  }

}
