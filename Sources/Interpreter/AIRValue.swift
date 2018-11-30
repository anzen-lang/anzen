import AST

/// The protocol for AIR values.
///
/// An AIR value can be anything that represents a first-class value in AIR, such as, for instance,
/// a literal or a register. Note that instructions that produce a value (e.g. `alloc`) are also
/// represented as values themselves.
public protocol AIRValue {

  /// The type of the value.
  var type: TypeBase { get }
  /// The text description of the value.
  var valueDescription: String { get }

}

/// The protocol for AIR registers.
///
/// An AIR register is an AIR value that can be represented as a register.
public protocol AIRRegister: AIRValue {

  /// The name of the register.
  var name: String { get }

}

/// Represents a function closure
public struct AIRClosure: AIRValue {

  internal init(function: AIRFunction, arguments: [AIRValue], type: FunctionType) {
    self.function = function
    self.arguments = arguments
    self.type = type
  }

  public let function: AIRFunction
  public let arguments: [AIRValue]
  public let type: TypeBase

  public var valueDescription: String {
    let arguments = self.arguments.map({ $0.valueDescription }).joined(separator: ", ")
    return "closure($\(function.valueDescription), \(arguments)"
  }

}

/// This represents a literal value in AIR.
public struct AIRLiteral: AIRValue {

  internal init(value: Bool, type: TypeBase) {
    self.value = value
    self.type = type
  }

  internal init(value: Int, type: TypeBase) {
    self.value = value
    self.type = type
  }

  internal init(value: Double, type: TypeBase) {
    self.value = value
    self.type = type
  }

  internal init(value: String, type: TypeBase) {
    self.value = value
    self.type = type
  }

  public let value: Any
  public let type: TypeBase

  public var valueDescription: String {
    return value is String ? "\"\(value)\"" : "\(value)"
  }

}
