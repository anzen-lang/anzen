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
    return (self != other) && (other == AnythingType.get)
  }

  /// Opens the type, replacing occurences of placeholders with fresh variables.
  public func open(
    using bindings: [PlaceholderType: TypeVariable] = [:],
    in context: ASTContext) -> TypeBase
  {
    return self
  }

  /// Closes the type, effectively replacing its placeholders with their given substitution.
  public func close(
    using bindings: [PlaceholderType: TypeBase] = [:],
    in context: ASTContext) -> TypeBase
  {
    return self
  }

  public static func == (lhs: TypeBase, rhs: TypeBase) -> Bool {
    return lhs === rhs
  }

}

/// Class to represent the description of a type.
public final class Metatype: TypeBase, CustomStringConvertible {

  fileprivate init(of type: TypeBase) {
    self.type = type
  }

  public let type: TypeBase

  /// Opens the type, replacing occurences of placeholders with fresh variables.
  public override func open(
    using bindings: [PlaceholderType: TypeVariable] = [:],
    in context: ASTContext) -> TypeBase
  {
    return type.open(using: bindings, in: context).metatype
  }

  public var description: String {
    return "\(type).metatype"
  }

}

/// Anzen's `Anything` type.
public final class AnythingType: TypeBase, CustomStringConvertible {

  public static let get = AnythingType()

  public let description = "Anything"

}

/// Anzen's `Nothing` type.
public final class NothingType: TypeBase, CustomStringConvertible {

  public static let get = NothingType()

  public let description = "Nothing"

}

/// A special type that's used to represent a typing failure.
public final class ErrorType: TypeBase, CustomStringConvertible {

  public static let get = ErrorType()

  public let description = "<error type>"

}

/// A type variable used during type checking.
public final class TypeVariable: TypeBase, Hashable, CustomStringConvertible {

  public override init() {
    self.id = TypeVariable.nextID
    TypeVariable.nextID += 1
  }

  public let id: Int
  private static var nextID = 0

  /// Opens the type, replacing occurences of placeholders with fresh variables.
  public override func open(
    using bindings: [PlaceholderType: TypeVariable] = [:],
    in context: ASTContext) -> TypeBase
  {
    return BoundGenericType(unboundType: self, bindings: bindings)
  }

  /// Closes the type, effectively replacing its placeholders with their given substitution.
  public override func close(
    using bindings: [PlaceholderType: TypeBase] = [:],
    in context: ASTContext) -> TypeBase
  {
    return self
  }

  public var hashValue: Int {
    return id
  }

  public var description: String {
    return "$\(id)"
  }

}

/// A type placeholder, a.k.a. a generic parameter.
public final class PlaceholderType: TypeBase, Hashable, CustomStringConvertible {

  public required init(name: String) {
    self.name = name
  }

  /// The name of the placeholder.
  public let name: String

  /// Opens the type, replacing occurences of placeholders with fresh variables.
  public override func open(
    using bindings: [PlaceholderType: TypeVariable] = [:],
    in context: ASTContext) -> TypeBase
  {
    return bindings[self] ?? self
  }

  /// Closes the type, effectively replacing its placeholders with their given substitution.
  public override func close(
    using bindings: [PlaceholderType: TypeBase] = [:],
    in context: ASTContext) -> TypeBase
  {
    assert(bindings.keys.contains(self), "partial specializations aren't supported yet")
    return bindings[self]!
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(name)
  }

  public var description: String {
    return name
  }

}

/// Protocol for types that may have generic placeholders.
public protocol GenericType {

  /// The type placeholders of the generic type.
  var placeholders: [PlaceholderType] { get }

}

/// Class to represent a possibly incomplete type whose placeholders have been fixed.
public final class BoundGenericType: TypeBase, CustomStringConvertible {

  public init(unboundType: TypeBase, bindings: [PlaceholderType: TypeBase]) {
    self.unboundType = unboundType
    self.bindings = bindings
  }

  /// The generic type with unbound placeholders.
  public let unboundType: TypeBase
  /// The unbound placeholder assignments.
  public let bindings: [PlaceholderType: TypeBase]

  /// Opens the type, replacing occurences of placeholders with fresh variables.
  public override func open(
    using bindings: [PlaceholderType: TypeVariable] = [:],
    in context: ASTContext) -> TypeBase
  {
    let updatedBindings = [PlaceholderType: TypeBase](
      uniqueKeysWithValues: self.bindings.map({ (key, value) in
        (key, (value as? PlaceholderType).flatMap({ bindings[$0] }) ?? value)
      }))
    return BoundGenericType(unboundType: unboundType, bindings: updatedBindings)
  }

  /// Closes the type, effectively replacing its placeholders with their given substitution.
  public override func close(
    using bindings: [PlaceholderType: TypeBase] = [:],
    in context: ASTContext) -> TypeBase
  {
    let updatedBindings = Dictionary(
      uniqueKeysWithValues: self.bindings.map({ (key, value) in
        (key, (value as? PlaceholderType).flatMap({ bindings[$0] }) ?? value)
      }))
    return unboundType.close(using: updatedBindings, in: context)
  }

  public var description: String {
    let placeholders = bindings.map({ "\($0.key)=\($0.value)" }).joined(separator: ", ")
    return "<\(placeholders)>\(unboundType)"
  }

}

/// Class to represent types whose name can be use to distinguish structurally-similar types.
public class NominalType: TypeBase, GenericType, Hashable, CustomStringConvertible {

  public required init(decl: NominalTypeDecl, memberScope: Scope?, isBuiltin: Bool = false) {
    self.decl = decl
    self.memberScope = memberScope
    self.isBuiltin = isBuiltin
  }

  /// The node that declares this type.
  public unowned let decl: NominalTypeDecl
  /// The scope of the type's members.
  public let memberScope: Scope?
  /// The type placeholders of the type, in case the type's generic.
  public var placeholders: [PlaceholderType] = []
  /// The members of the type.
  public var members: [Symbol] = []
  /// Whether the type is built-in.
  public let isBuiltin: Bool

  /// The name of the type.
  public var name: String { return decl.name }

  /// Returns whether this type is a subtype of another.
  public override func isSubtype(of other: TypeBase) -> Bool {
    // FIXME: Handle interface conformance.
    return (self != other) && (other == AnythingType.get)
  }

  /// Opens the type, replacing occurences of placeholders with fresh variables.
  public override func open(
    using bindings: [PlaceholderType: TypeVariable] = [:],
    in context: ASTContext) -> TypeBase
  {
    unreachable()
  }

  /// Closes the type, effectively replacing its placeholders with their given substitution.
  ///
  /// - Remark: We intentionally don't reify bound nominal types, so as to preserve the parameters
  ///   with which they should be bound.
  public override func close(
    using bindings: [PlaceholderType: TypeBase] = [:],
    in context: ASTContext) -> TypeBase
  {
    let typeBindings = bindings.filter { placeholders.contains($0.key) }
    return placeholders.isEmpty
      ? self
      : BoundGenericType(unboundType: self, bindings: typeBindings)
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(name)
    for ph in placeholders {
      hasher.combine(ph)
    }
  }

  public var description: String {
    return !placeholders.isEmpty
      ? name + "<" + placeholders.map({ $0.name }).joined(separator: ", ") + ">"
      : name
  }

}

/// A struct type.
public final class StructType: NominalType {}

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
      return other == AnythingType.get
    }

    guard domain.count == rhs.domain.count else { return false }
    for (pl, pr) in zip(domain, rhs.domain) {
      guard pl.type.isSubtype(of: pr.type) && pl.label == pr.label else { return false }
    }
    return codomain.isSubtype(of: rhs.codomain)
  }

  /// Opens the type, replacing occurences of placeholders with fresh variables.
  public override func open(
    using bindings: [PlaceholderType: TypeVariable] = [:],
    in context: ASTContext) -> TypeBase
  {
    // Make sure the type needs to be open.
    guard !placeholders.isEmpty
      else { return self }

    // As functions do not need to retain which types their placeholders were bound to, opening one
    // amounts to create a new monomorphic version where placeholder are substituted.
    let updatedBindings = bindings.merging(
      placeholders.map { (key: $0, value: TypeVariable()) },
      uniquingKeysWith: { lhs, _ in lhs })
    return context.getFunctionType(
      from: domain.map({
        Parameter(label: $0.label, type: $0.type.open(using: updatedBindings, in: context))
      }),
      to: codomain.open(using: updatedBindings, in: context))
  }

  /// Closes the type, effectively replacing its placeholders with their given substitution.
  public override func close(
    using bindings: [PlaceholderType: TypeBase] = [:],
    in context: ASTContext) -> TypeBase
  {
    let domain = self.domain.map {
      Parameter(label: $0.label, type: $0.type.close(using: bindings, in: context))
    }
    let codomain = self.codomain.close(using: bindings, in: context)
    return context.getFunctionType(from: domain, to: codomain)
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

  public init(label: String? = nil, type: TypeBase) {
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

/// Attempts to match a generic type with another type.
public func specializes(
  lhs: TypeBase,
  rhs: TypeBase,
  in context: ASTContext,
  bindings: inout [PlaceholderType: TypeBase]) -> Bool
{
  switch (lhs, rhs) {
  case (_, _) where lhs == rhs:
    return true

  case (_, let right as PlaceholderType):
    if let type = bindings[right] {
      return specializes(lhs: lhs, rhs: type, in: context, bindings: &bindings)
    }
    bindings[right] = lhs
    return true

  case (let left as BoundGenericType, _):
    let closed = left.unboundType is NominalType
      ? left.unboundType
      : left.close(using: left.bindings, in: context)
    return specializes(lhs: closed, rhs: rhs, in: context, bindings: &bindings)

  case (_, let right as BoundGenericType):
    return specializes(lhs: right, rhs: lhs, in: context, bindings: &bindings)

  case (let left as Metatype, let right as Metatype):
    return specializes(lhs: left.type, rhs: right.type, in: context, bindings: &bindings)

  case (let left as FunctionType, let right as FunctionType):
    if left.placeholders.isEmpty && right.placeholders.isEmpty {
      return left == right
    }

    guard left.domain.count == right.domain.count
      else { return false }
    for params in zip(left.domain, right.domain) {
      guard params.0.label == params.1.label
        else { return false }
      guard specializes(lhs: params.0.type, rhs: params.1.type, in: context, bindings: &bindings)
        else { return false }
    }
    return specializes(lhs: left.codomain, rhs: right.codomain, in: context, bindings: &bindings)

  case (is TypeVariable, _), (_, is TypeVariable):
    preconditionFailure("Unexpected type variable, did you forget to reify?")

  default:
    return false
  }
}
