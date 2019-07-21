/// A value pointer.
///
/// A value pointer is merely a reference to a value container. It should be replaced by an actual
/// raw pointer once RAII is implemented.
final class ValuePointer: CustomStringConvertible {

  /// The pointed value.
  var pointee: ValueContainer

  init(to pointee: ValueContainer) {
    self.pointee = pointee
  }

  var description: String {
    return "ValuePointer(to: \(pointee))"
  }

}
