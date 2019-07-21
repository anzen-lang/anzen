/// An AIR value.
///
/// This protocol represents any value a program may compute and use as compound of other values.
/// Very intuitively, a literal is an AIR value, but so is `alloc` (i.e. the instruction that
/// allocates register), as the latter represents the "value" of a register.
public protocol AIRValue {

  /// The type of the value.
  var type: AIRType { get }
  /// The text description of the value.
  var valueDescription: String { get }

}

/// An AIR register.
///
/// An AIR register is an AIR value that can be represented as a register.
public protocol AIRRegister: AIRValue {

  /// The ID of the register.
  var id: Int { get }

}

/// An AIR constant.
public struct AIRConstant: AIRValue {

  internal init(value: Bool) {
    self.value = value
    self.type = AIRBuiltinType.bool
  }

  internal init(value: Int) {
    self.value = value
    self.type = AIRBuiltinType.int
  }

  internal init(value: Double) {
    self.value = value
    self.type = AIRBuiltinType.float
  }

  internal init(value: String) {
    self.value = value
    self.type = AIRBuiltinType.string
  }

  public let value: Any
  public let type: AIRType

  public var valueDescription: String {
    return value is String
      ? "\"\(value)\""
      : "\(value)"
  }

}

/// An AIR null value.
public struct AIRNull: AIRValue {

  internal init(type: AIRType) {
    self.type = type
  }

  public let type: AIRType

  public var valueDescription: String {
    return "null"
  }

}
