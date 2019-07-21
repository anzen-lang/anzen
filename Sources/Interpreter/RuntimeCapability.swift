/// A reference's state.
enum ReferenceState {

  /// The capability for references to unaliased objects.
  case unique

  /// The capability for owning references to aliased objects.
  case shared(count: Int)

  /// The capability for borrowed references.
  case borrowed(owner: Reference)

  /// The capability for uninitialized references.
  case uninitialized

  /// The capability for moved references.
  case moved

}
