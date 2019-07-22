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
  /// The debug information associated with this value.
  var debugInfo: DebugInfo? { get }

}

/// An AIR register.
///
/// An AIR register is an AIR value that can be represented as a register.
public protocol AIRRegister: AIRValue {

  /// The ID of the register.
  var id: Int { get }

}

/// An AIR constant value.
public struct AIRConstant: AIRValue {

  /// The value of an AIR constant.
  public enum Value: CustomStringConvertible {

    case bool(Bool)
    case integer(Int)
    case float(Double)
    case string(String)

    public var description: String {
      switch self {
      case .bool(let value):
        return "\(value)"
      case .integer(let value):
        return "\(value)"
      case .float(let value):
        return "\(value)"
      case .string(let value):
        return "\"\(value)\""
      }
    }

  }

  /// The constant's value.
  public let value: Value

  public let type: AIRType
  public let debugInfo: DebugInfo?

  internal init(value: Bool, debugInfo: DebugInfo?) {
    self.value = .bool(value)
    self.type = AIRBuiltinType.bool
    self.debugInfo = debugInfo
  }

  internal init(value: Int, debugInfo: DebugInfo?) {
    self.value = .integer(value)
    self.type = AIRBuiltinType.int
    self.debugInfo = debugInfo
  }

  internal init(value: Double, debugInfo: DebugInfo?) {
    self.value = .float(value)
    self.type = AIRBuiltinType.float
    self.debugInfo = debugInfo
  }

  internal init(value: String, debugInfo: DebugInfo?) {
    self.value = .string(value)
    self.type = AIRBuiltinType.string
    self.debugInfo = debugInfo
  }

  public var valueDescription: String {
    return "\(value)"
  }

}

/// An AIR null value.
public struct AIRNull: AIRValue {

  public let type: AIRType
  public let debugInfo: DebugInfo?

  internal init(type: AIRType, debugInfo: DebugInfo?) {
    self.type = type
    self.debugInfo = debugInfo
  }

  public var valueDescription: String {
    return "null"
  }

}
