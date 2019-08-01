public func unreachable() -> Never {
  fatalError("unreachable path")
}

public func notImplementedError() -> Never {
  fatalError("not implemented")
}

//@inline(__always)
//public func unreachable() -> Never {
//    return unsafeBitCast((), to: Never.self)
//}
