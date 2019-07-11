/// A named symbol.
public class Symbol {

  internal init(
    name: String, scope: Scope, type: TypeBase?, isOverloadable: Bool, isMethod: Bool, isStatic: Bool)
  {
    self.name = name
    self.scope = scope
    self.type = type
    self.isOverloadable = isOverloadable
    self.isMethod = isMethod
    self.isStatic = isStatic
  }

  /// The name of the symbol.
  public let name: String
  /// The type of the symbol.
  public var type: TypeBase?
  /// Indicates whether the symbol is overloadable.
  public let isOverloadable: Bool
  /// Indicates whether the symbol is associated with a method.
  public let isMethod: Bool
  /// Indicates whether the symbol is associated with a static member.
  public let isStatic: Bool
  /// The scope that defines this symbol.
  public unowned let scope: Scope

}

extension Symbol: Hashable {

  public func hash(into hasher: inout Hasher) {
    hasher.combine(name)
    hasher.combine(scope)
  }

  public static func == (lhs: Symbol, rhs: Symbol) -> Bool {
    return lhs === rhs
  }

}
