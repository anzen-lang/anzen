import Dispatch

public struct Stopwatch {

  public struct TimeInterval {
    public let ns: UInt64
    public var μs: Double { return Double(ns) / 1_000 }
    public var ms: Double { return Double(ns) / 1_000_000 }
    public var s : Double { return Double(ns) / 1_000_000_000 }

    public var humanFormat: String {
      guard ns >= 1_000 else { return "\(ns)ns" }
      guard ns >= 1_000_000 else { return "\((μs * 100).rounded() / 100)μs" }
      guard ns >= 1_000_000_000 else { return "\((ms * 100).rounded() / 100)ms" }
      guard ns >= 1_000_000_000_000 else { return "\((s * 100).rounded() / 100)s" }

      var minutes = ns / 60_000_000_000_000
      let seconds = ns % 60_000_000_000_000
      guard minutes >= 60 else { return "\(minutes)m \(seconds)s" }

      let hours = minutes / 60
      minutes = minutes % 60
      return "\(hours)h \(minutes)m \(seconds)s"
    }
  }

  public init() {
    startTime = DispatchTime.now()
  }

  public mutating func reset() {
    startTime = DispatchTime.now()
  }

  public var elapsed: TimeInterval {
    let nano = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
    return TimeInterval(ns: nano)
  }

  private var startTime: DispatchTime

}
