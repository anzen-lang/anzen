import AST

/// The protocol for AIR values.
///
/// An AIR value can be anything that represents a first-class value in AIR, such as, for instance,
/// a literal or a register. Note that instructions that produce a value (e.g. `newref`) are also
/// represented as values themselves.
public protocol AIRValue {

  /// The type of the value.
  var type: TypeBase { get }
  /// The text description of the value.
  var valueDescription: String { get }

}

/// This represents a literal value in AIR.
public struct AIRLiteral: AIRValue {

  internal init(value: Int, type: TypeBase) {
    self.value = value
    self.type = type
  }

  public let value: Any
  public let type: TypeBase

  public var valueDescription: String {
    return value is String ? "\"\(value)\"" : "\(value)"
  }

}
