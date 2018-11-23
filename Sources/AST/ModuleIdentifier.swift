import SystemKit
import Utils

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
    case .builtin       : return "__builtin"
    case .stdlib        : return "__stdlib"
    case .local(let path):
      let relative = path.relative(to: .workingDirectory)
      return relative.pathname
        .dropLast(relative.fileExtension.map { $0.count + 1 } ?? 0)
        .replacing("../", with: ".")
        .replacing("/", with: ".")
    }
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
