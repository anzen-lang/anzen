public protocol OptionalConvertible {

  associatedtype Wrapped

  var optional: Wrapped? { get }

}

extension Optional: OptionalConvertible {

  public var optional: Wrapped? { return self }

}
