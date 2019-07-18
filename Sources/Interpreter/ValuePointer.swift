/// A value pointer.
class ValuePointer: CustomStringConvertible {

  /// The pointed value.
  var pointee: ValueContainer

  init(to pointee: ValueContainer) {
    self.pointee = pointee
  }

  var description: String {
    return "ValuePointer(to: \(pointee))"
  }

}
