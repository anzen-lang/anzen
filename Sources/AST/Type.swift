import Utils

/// Base class for all types in Anzen.
public class TypeBase: Equatable {

  fileprivate init() {}

  /// The metatype of the type.
  public lazy var metatype: Metatype = { [unowned self] in
    return Metatype(of: self)
  }()

  /// Returns whether this type is a subtype of another.
  public func isSubtype(of other: TypeBase) -> Bool {
    return false
  }

  public static func == (lhs: TypeBase, rhs: TypeBase) -> Bool {
    return lhs === rhs
  }

  /// The built-in `Anything` type, which represents the top of the lattice.
  public static let anything = StructType(name: "Anything")
  /// The built-in `Nothing` type, which represents the bottom of the lattice.
  public static let nothing = StructType(name: "Nothing")

}

/// Class to represent the description of a type.
public final class Metatype: TypeBase, CustomStringConvertible {

  fileprivate init(of type: TypeBase) {
    self.type = type
  }

  public let type: TypeBase

  public var description: String {
    return "\(type).metatype"
  }

}

/// A special type that's used to represent a typing failure.
public final class ErrorType: TypeBase, CustomStringConvertible {

  public static let get = ErrorType()

  public var description: String {
    return "<error type>"
  }

}

/// A type variable used during type checking.
public final class TypeVariable: TypeBase, Hashable, CustomStringConvertible {

  public override init() {
    self.id = TypeVariable.nextID
    TypeVariable.nextID += 1
  }

  public let id: Int
  private static var nextID = 0

  public var hashValue: Int {
    return id
  }

  public var description: String {
    return "τ\(id)"
  }

}

/// Protocol for types that may have generic placeholders.
public protocol GenericType {

  /// The type placeholders of the generic type.
  var placeholders: [PlaceholderType] { get }

}

/// Class to represent a possibly incomplete type whose placeholders have been fixed.
public final class ClosedGenericType: TypeBase, CustomStringConvertible {

  public init(unboundType: TypeBase, bindings: [PlaceholderType: TypeBase]) {
    self.unboundType = unboundType
    self.bindings = bindings
  }

  /// The generic type with unbound placeholders.
  public let unboundType: TypeBase
  /// The unbound placeholder assignments.
  public let bindings: [PlaceholderType: TypeBase]

  public var description: String {
    let placeholders = bindings.map({ "\($0.key)=\($0.value)" }).joined(separator: ", ")
    return "<\(placeholders)>\(unboundType)"
  }

}

/// Class to represent types whose name can be use to distinguish structurally-similar types.
public class NominalType: TypeBase, GenericType, Hashable, CustomStringConvertible {

  public required init(name: String) {
    self.name = name
  }

  /// The name of the type.
  public let name: String
  /// The type placeholders of the type, in case the type's generic.
  public var placeholders: [PlaceholderType] = []
  /// The members of the type.
  public var members: [String: [TypeBase]] = [:]

  /// Returns whether this type is a subtype of another.
  public override func isSubtype(of other: TypeBase) -> Bool {
    // FIXME: Handle interface conformance.
    return (self != other) && (other == TypeBase.anything)
  }

  public var hashValue: Int {
    var h = 31 &* name.hashValue
    for ph in placeholders {
      h = 31 &* h &+ ph.hashValue
    }
    return h
  }

  public var description: String {
    return !placeholders.isEmpty
      ? name + "<" + placeholders.map({ $0.name }).joined(separator: ", ") + ">"
      : name
  }

}

/// A type placeholder, a.k.a. a generic parameter.
public final class PlaceholderType: NominalType {}

/// A struct type.
public final class StructType: NominalType {}

/// Class to represent a opened nominal generic type that hasn't been been closed yet.
public final class OpenedNominalType: TypeBase, CustomStringConvertible {

  public init(unboundType: NominalType, bindings: [PlaceholderType: TypeVariable]) {
    self.unboundType = unboundType
    self.bindings = bindings
  }

  /// The generic type with unbound placeholders.
  public let unboundType: NominalType
  /// The fresh variables used for which placeholders are substituted.
  public let bindings: [PlaceholderType: TypeVariable]

  public var description: String {
    return "opened(\(unboundType))"
  }

}

/// Class to represent function types.
public final class FunctionType: TypeBase, GenericType, CustomStringConvertible {

  internal init(domain: [Parameter], codomain: TypeBase, placeholders: [PlaceholderType]) {
    self.domain = domain
    self.codomain = codomain
    self.placeholders = placeholders
  }

  /// The domain of the function.
  public let domain: [Parameter]
  /// The codomain of the function.
  public let codomain: TypeBase
  /// The type placeholders of the type, in case the type's generic.
  public let placeholders: [PlaceholderType]

  /// Returns whether this type is a subtype of another.
  public override func isSubtype(of other: TypeBase) -> Bool {
    guard let rhs = other as? FunctionType else {
      return other == TypeBase.anything
    }

    guard domain.count == rhs.domain.count else { return false }
    for (pl, pr) in zip(domain, rhs.domain) {
      guard pl.type.isSubtype(of: pr.type) && pl.label == pr.label else { return false }
    }
    return codomain.isSubtype(of: rhs.codomain)
  }

  public var description: String {
    let params = domain.map({ $0.description }).joined(separator: ", ")
    return !placeholders.isEmpty
      ? "<" + placeholders.map({ $0.name }).joined(separator: ", ") + "> (\(params)) -> \(codomain)"
      : "(\(params)) -> \(codomain)"
  }

}

/// A function parameter.
public struct Parameter: Equatable, CustomStringConvertible {

  public init(label: String?, type: TypeBase) {
    self.label = label
    self.type = type
  }

  public let label: String?
  public let type: TypeBase

  public var description: String {
    return "\(label ?? "_"): \(type)"
  }

  public static func == (lhs: Parameter, rhs: Parameter) -> Bool {
    return (lhs.label == rhs.label) && (lhs.type == rhs.type)
  }

}
