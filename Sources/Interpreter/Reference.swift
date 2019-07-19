import AnzenIR

/// Represents a reference to a value container.
///
/// At runtime, all AIR registers are bound to references, which are pointers to value containers.
/// In C's parlance, a reference is a pointer to a pointer to some value. This additional level of
/// indirections enables the support of AIR's different assignment semantics, and gives the
/// opportunity to attach runtime capabilities to each reference.
///
/// Note that reference identity is actually computed on the referred value containers, as those
/// actually represent the values being manipulated.
class Reference: CustomStringConvertible {

  /// The value pointer to which this reference refers.
  ///
  /// If this property is `nil`, the reference is said to be `null`.
  var pointer: ValuePointer?

  /// The type of the pointed value.
  ///
  /// - Note:
  ///   Because of polymorphism, the type of the reference is not necessarily identical to referred
  ///   value's type. It is however guaranteed to be a supertype thereof.
  let type: AIRType

  init(to pointer: ValuePointer? = nil, type: AIRType) {
    self.pointer = pointer
    self.type = type
  }

  var description: String {
    if let pointer = self.pointer {
      return withUnsafePointer(to: pointer) {
        "Reference(to: \(pointer) @ \($0)"
      }
    } else {
      return "null"
    }
  }

}
