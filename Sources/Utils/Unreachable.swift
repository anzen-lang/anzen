public func unreachable() -> Never {
  fatalError("unreachable path")
}

//@inline(__always)
//public func unreachable() -> Never {
//    return unsafeBitCast((), to: Never.self)
//}
