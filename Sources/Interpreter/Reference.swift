import AnzenIR

/// Represents a reference.
///
/// A reference contains a pointer to a value.
class Reference: CustomStringConvertible {

  /// The value pointer to which this reference refers.
  var pointer: ValuePointer?

  /// The type of the pointed value.
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
