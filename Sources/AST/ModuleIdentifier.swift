/// Enum representing a module identifier.
public enum ModuleIdentifier: Hashable {

  case builtin
  case stdlib
  case local(name: String)

  /// The qualified name corresponding to this module identifier.
  public var qualifiedName: String {
    switch self {
    case .builtin:
      return "Anzen"
    case .stdlib:
      return "Anzen.stdlib"
    case .local(let name):
      return name
    }
  }

  public var hashValue: Int {
    switch self {
    case .builtin:
      return 0
    case .stdlib:
      return 1
    case .local(name: let name):
      return name.hashValue
    }
  }

  public static func == (lhs: ModuleIdentifier, rhs: ModuleIdentifier) -> Bool {
    switch (lhs, rhs) {
    case (.builtin, .builtin):
      return true
    case (.stdlib, .stdlib):
      return true
    case (.local(name: let left), .local(name: let right)):
      return left == right
    default:
      return false
    }
  }

}
