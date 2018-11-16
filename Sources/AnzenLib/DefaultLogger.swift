import SystemKit

public struct DefaultLogger: Logger {

  public init(verbosity: Verbosity) {
    self.verbosity = verbosity
  }

  /// The logger's verbosity.
  public var verbosity: Verbosity

  /// Logs the given text, only if the logger's verbosity is higher than `verbose`.
  public func verbose(_ text: @autoclosure () -> String) {
    if verbosity >= .verbose {
      System.err.print(text())
    }
  }

  /// Logs the given text, only if the logger's verbosity is higher than `debug`.
  public func debug(_ text: @autoclosure () -> String) {
    if verbosity >= .debug {
      System.err.print(text())
    }
  }

  /// Logs the given text, only if the logger's verbosity is higher than `debug`.
  public func write(_ text: String) {
    System.err.write(text)
  }

}
