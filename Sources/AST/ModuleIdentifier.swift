import Utils

/// Enum representing a module identifier.
public enum ModuleIdentifier: Hashable {

  /// Identifies Anzen's built-in module.
  case builtin
  /// Identifies Anzen's standard library module.
  case stdlib
  /// Identifies a module by its URL.
  case url(Path)

  /// The qualified name corresponding to this module identifier.
  public var qualifiedName: String {
    switch self {
    case .builtin: return "anzen://builtin"
    case .stdlib: return "anzen://stdlib"
    case .url(let path): return path.url
    }
  }

  public var hashValue: Int {
    return qualifiedName.hashValue
  }

  public static func == (lhs: ModuleIdentifier, rhs: ModuleIdentifier) -> Bool {
    switch (lhs, rhs) {
    case (.builtin, .builtin): return true
    case (.stdlib, .stdlib): return true
    case (.url(let lhs), .url(let rhs)): return lhs == rhs
    default: return false
    }
  }

}
