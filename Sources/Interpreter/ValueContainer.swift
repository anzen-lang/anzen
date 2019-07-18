import AnzenIR

/// A container for a value at runtime.
class ValueContainer: CustomStringConvertible {

  /// The type of the value.
  let type: AIRType

  fileprivate init(type: AIRType) {
    self.type = type
  }

  /// Returns a deep copy of this value.
  func copy() -> ValueContainer {
    // Implements the fly-weight pattern by default.
    return self
  }

  /// Drops this value.
  func drop() {
  }

  var description: String {
    return "(Object)"
  }

}

/// A primitive type.
protocol PrimitiveType {

  var airType: AIRType { get }

}

extension Bool: PrimitiveType {

  var airType: AIRType { return AIRType.bool }

}

extension Int: PrimitiveType {

  var airType: AIRType { return AIRType.int }

}

extension Double: PrimitiveType {

  var airType: AIRType { return AIRType.float }

}
extension String: PrimitiveType {

  var airType: AIRType { return AIRType.string }

}

/// A primitive value.
class PrimitiveValue: ValueContainer {

  let value: PrimitiveType

  init(_ value: PrimitiveType) {
    self.value = value
    super.init(type: value.airType)
  }

  override var description: String {
    return "\(value)"
  }

}

/// A struct instance.
class StructInstance: ValueContainer {

  /// The struct's members.
  let payload: [Reference]

  init(type: AIRStructType) {
    self.payload = type.members.map { (_, type) in Reference(type: type) }
    super.init(type: type)
  }

  override var description: String {
    let type = self.type as! AIRStructType
    let members = zip(type.members.keys, payload)
      .map({ "\($0.0): \($0.1)" })
      .joined(separator: ", ")
    return "\(type)(\(members))"
  }

}

/// Represents a function.
class FunctionValue: ValueContainer {

  /// The underlying (thin) function.
  let function: AIRFunction

  /// The arguments captured by the closure.
  let closure: [AIRValue]

  init(function: AIRFunction, closure: [AIRValue] = [], type: AIRFunctionType? = nil) {
    self.function = function
    self.closure = closure
    super.init(type: type ?? function.type)
  }

  override var description: String {
    return "(Function)"
  }

}
