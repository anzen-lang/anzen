/// A named symbol.
public class Symbol {

  /// The name of the symbol.
  public let name: String
  /// The type of the symbol.
  public var type: TypeBase?
  /// The symbol's attributes.
  public let attributes: SymbolAttributes
  /// The scope that defines this symbol.
  public unowned let scope: Scope

  internal init(name: String, scope: Scope, type: TypeBase?, attributes: SymbolAttributes) {
    self.name = name
    self.scope = scope
    self.type = type
    self.attributes = attributes
  }

  /// Indicates whether the symbol is overloadable.
  public var isOverloadable: Bool { return attributes.contains(.overloadable) }
  /// Indicates whether the symbol is reassignable.
  public var isReassignable: Bool { return attributes.contains(.reassignable) }
  /// Indicates whether the symbol is associated with a static member.
  public var isStatic: Bool { return attributes.contains(.static) }
  /// Indicates whether the symbol is associated with a method.
  public var isMethod: Bool { return attributes.contains(.method) }

}

/// The attributes of a given symbol.
public struct SymbolAttributes: OptionSet {

  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public static let none         = SymbolAttributes(rawValue: 0)
  public static let overloadable = SymbolAttributes(rawValue: 1 << 0)
  public static let reassignable = SymbolAttributes(rawValue: 1 << 1)
  public static let `static`     = SymbolAttributes(rawValue: 1 << 2)
  public static let method       = SymbolAttributes(rawValue: 1 << 3)

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
