/// A reference's memory state.
enum MemoryState {

  /// The state for references to unaliased objects.
  case unique

  /// The state for owning references to aliased objects.
  case shared(count: Int)

  /// The state for borrowed references.
  case borrowed(owner: Reference?)

  /// The state for uninitialized references.
  case uninitialized

  /// The state for moved references.
  case moved

}
