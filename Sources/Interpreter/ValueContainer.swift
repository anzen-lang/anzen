import AnzenIR

/// A container for a value at runtime.
///
/// A value container is a wrapper around a value that abstracts over the operation thereupon.
/// Those describe how to copy and deallocate the wrapped value.
///
/// - Note:
///   This design is heavily inspired by Swift's existential containers (see "Understanding Swift
///   Performance", WWDC 2016, Session 416).
///
/// - Todo:
///   In the future, value containers should also contain a virtual method table (a.k.a. a witness
///   table in Swift) to support dynamic dispatch on polymorphic references.
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
final class PrimitiveValue: ValueContainer {

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
final class StructInstance: ValueContainer {

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
final class FunctionValue: ValueContainer {

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
