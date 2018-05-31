/// A named symbol.
public class Symbol {

  internal init(
    name: String, scope: Scope, type: TypeBase?, overloadable: Bool)
  {
    self.name = name
    self.scope = scope
    self.type = type
    self.overloadable = overloadable
  }

  /// The name of the symbol.
  public let name: String
  /// The type of the symbol.
  public var type: TypeBase?
  /// Let function symbols be marked overloadable.
  public let overloadable: Bool
  /// The scope that defines this symbol.
  public unowned let scope: Scope

}

extension Symbol: Hashable {

  public var hashValue: Int {
    return 31 &* self.name.hashValue &+ self.scope.id
  }

  public static func == (lhs: Symbol, rhs: Symbol) -> Bool {
    return lhs === rhs
  }

}
