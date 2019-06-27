/// A mapping from names to symbols.
///
/// This collection stores the symbols that are declared within a scope (e.g. a function scope).
/// It is a mapping `String -> [Symbol]`, as a symbol names may be overloaded.
public class Scope {

  public init(name: String? = nil, parent: Scope? = nil, module: ModuleDecl? = nil) {
    // Create a unique ID for the scope.
    self.id = Scope.nextID
    Scope.nextID += 1

    self.name = name
    self.parent = parent
    self.module = module ?? parent?.module
  }

  /// Returns whether or not a symbol with the given name exists in this scope.
  public func defines(name: String) -> Bool {
    if let symbols = self.symbols[name] {
      return !symbols.isEmpty
    }
    return false
  }

  /// Returns whether this scope is an ancestor of the given one.
  public func isAncestor(of other: Scope) -> Bool {
    var ancestor = other.parent
    while ancestor != nil {
      if ancestor == self {
        return true
      }
      ancestor = ancestor?.parent
    }
    return false
  }

  /// Create a symbol in this scope.
  @discardableResult
  public func create(
    name: String,
    type: TypeBase?,
    isOverloadable: Bool = false,
    isMethod: Bool = false) -> Symbol
  {
    if symbols[name] == nil {
      symbols[name] = []
    }
    precondition(symbols[name]!.all(satisfy: { $0.isOverloadable }))
    let symbol = Symbol(
      name: name, scope: self, type: type, isOverloadable: isOverloadable, isMethod: isMethod)
    symbols[name]!.append(symbol)
    return symbol
  }

  public weak var parent: Scope?
  public weak var module: ModuleDecl?

  public let id: Int
  public let name: String?
  public var symbols: [String: [Symbol]] = [:]

  fileprivate static var nextID = 0

}

extension Scope: Hashable {

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  public static func == (lhs: Scope, rhs: Scope) -> Bool {
    return lhs.id == rhs.id
  }

}

extension Scope: CustomStringConvertible {

  public var description: String {
    if let parent = self.parent {
      if parent.module?.id != .builtin && parent.module?.id != .stdlib {
        return "\(parent).\(self.name ?? self.id.description)"
      }
    }
    return self.name ?? self.id.description
  }
}
