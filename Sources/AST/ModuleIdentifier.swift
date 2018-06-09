import Utils
import SystemKit

/// Enum representing a module identifier.
public enum ModuleIdentifier: Hashable {

  /// Identifies Anzen's built-in module.
  case builtin
  /// Identifies Anzen's standard library module.
  case stdlib
  /// Identifies a module by its path.
  case local(Path)

  /// The qualified name corresponding to this module identifier.
  public var qualifiedName: String {
    switch self {
    case .builtin       : return "anzen://builtin"
    case .stdlib        : return "anzen://stdlib"
    case .local(let path):
      return path.hasSuffix(".anzen")
        ? String(path.pathname.dropLast(6))
        : path.pathname
    }
  }

  public var hashValue: Int {
    return qualifiedName.hashValue
  }

  public static func == (lhs: ModuleIdentifier, rhs: ModuleIdentifier) -> Bool {
    switch (lhs, rhs) {
    case (.builtin, .builtin): return true
    case (.stdlib, .stdlib): return true
    case (.local(let lhs), .local(let rhs)): return lhs == rhs
    default: return false
    }
  }

}
