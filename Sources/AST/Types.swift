/// A type qualifier set.
public struct TypeQualSet: OptionSet, Hashable {

  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public static let cst = TypeQualSet(rawValue: 1 << 0)
  public static let mut = TypeQualSet(rawValue: 1 << 1)

}

/// A qualified semantic type.
public struct QualType: Hashable {

  /// The unqualified type.
  public let bareType: TypeBase

  /// The type's qualifieirs.
  public let quals: TypeQualSet

  public init(bareType: TypeBase, quals: TypeQualSet) {
    self.bareType = bareType
    self.quals = quals
  }

}

/// A structure that stores various information about a type.
public struct TypeInfo {

  private let bits: Int

  public init(bits: Int) {
    self.bits = bits
  }

  public init(props: Int, typeID: Int) {
    // Stores the type ID in the 16 most significant bits.
    let n = Int.bitWidth - 16
    self.bits = (typeID << n) | props
  }

  /// The type's identifier, if any.
  var typeID: Int {
    let n = Int.bitWidth - 16
    let m = ((1 << 16) - 1) << n
    return (bits & m) >> n
  }

  /// Indicates a type in which one or more type variables occur.
  static let hasTypeVar = 1

  static func | (lhs: TypeInfo, rhs: TypeInfo) -> TypeInfo {
    return TypeInfo(bits: lhs.bits | rhs.bits)
  }

}

/// A semantic type.
public class TypeBase: Hashable {

  /// The compiler context.
  public unowned let context: CompilerContext

  /// Various information about this type.
  var info: TypeInfo

  /// The type's kind.
  public var kind: TypeKind { return context.getTypeKind(of: self) }

  /// The type qualified with the `@cst` qualifier.
  public var cst: QualType { return QualType(bareType: self, quals: [.cst]) }

  /// The type qualified with the `@mut` qualifier.
  public var mut: QualType { return QualType(bareType: self, quals: [.mut]) }

  /// Returns the set of unbound generic placeholders occuring in the type.
  public func getUnboundPlaceholders() -> Set<TypePlaceholder> {
    return []
  }

  internal init(context: CompilerContext, info: TypeInfo) {
    self.context = context
    self.info = info
  }

  public static func == (lhs: TypeBase, rhs: TypeBase) -> Bool {
    return lhs === rhs
  }

  public func hash(into hasher: inout Hasher) {
    let oid = ObjectIdentifier(self)
    hasher.combine(oid)
  }

  /// Returns whether two types are structurally equal, as opposed to identity equivalence.
  ///
  /// This method is intended to be overriden by type subclasses and used internally to guarantee
  /// instances' uniqueness throughout all compilation stages.
  internal func equals(to other: TypeBase) -> Bool {
    return self === other
  }

  /// Returns this type's structural hash.
  ///
  /// This method is intended to be overriden by type subclasses and used internally to compute the
  /// type hash values based on their structures rather than on their identity.
  internal func hashContents(into hasher: inout Hasher) {
    hash(into: &hasher)
  }

  /// Accepts a type transformer.
  public func accept<T>(transformer: T) -> T.Result where T: TypeTransformer {
    fatalError("call to abstract method 'accept(transformer:)'")
  }

}

/// A kind.
///
/// A kind (a.k.a. metatype) refers to the type of a type.
public final class TypeKind: TypeBase {

  /// The type constructed by this kind.
  public let type: TypeBase

  public override func getUnboundPlaceholders() -> Set<TypePlaceholder> {
    return type.getUnboundPlaceholders()
  }

  internal init(of type: TypeBase, context: CompilerContext, info: TypeInfo) {
    self.type = type
    super.init(context: context, info: info)
  }

  internal override func equals(to other: TypeBase) -> Bool {
    guard let rhs = other as? TypeKind
      else { return false }
    return self.type === rhs.type
  }

  public override func accept<T>(transformer: T) -> T.Result where T: TypeTransformer {
    return transformer.transform(self)
  }

}

/// A type variable used during type inference.
public final class TypeVar: TypeBase {
}

/// A type placeholder in a generic type.
public final class TypePlaceholder: TypeBase {

  /// The placeholder's decl.
  public unowned let decl: GenericParamDecl

  public override func getUnboundPlaceholders() -> Set<TypePlaceholder> {
    return Set([self])
  }

  internal init(decl: GenericParamDecl, context: CompilerContext, info: TypeInfo) {
    self.decl = decl
    super.init(context: context, info: info)
  }

  internal override func equals(to other: TypeBase) -> Bool {
    guard let rhs = other as? TypePlaceholder
      else { return false }
    return self.decl === rhs.decl
  }

  public override func accept<T>(transformer: T) -> T.Result where T: TypeTransformer {
    return transformer.transform(self)
  }

}

/// A type whose generic parameters have been (possibly partially) bound.
public final class BoundGenericType: TypeBase {

  /// The type with unbound generic parameters.
  public let type: TypeBase

  /// The generic parameters' assignments.
  public let bindings: [TypePlaceholder: TypeBase]

  public override func getUnboundPlaceholders() -> Set<TypePlaceholder> {
    return type.getUnboundPlaceholders().subtracting(bindings.keys)
  }

  internal init(
    type: TypeBase,
    bindings: [TypePlaceholder: TypeBase],
    context: CompilerContext,
    info: TypeInfo)
  {
    self.type = type
    self.bindings = bindings
    super.init(context: context, info: info)
  }

  internal override func equals(to other: TypeBase) -> Bool {
    guard let rhs = other as? BoundGenericType else { return false }
    return (self.type === rhs.type)
        && (self.bindings == rhs.bindings)
  }

  public override func accept<T>(transformer: T) -> T.Result where T: TypeTransformer {
    return transformer.transform(self)
  }

}

public final class FunType: TypeBase {

  /// A function type's parameter.
  public struct Param: Equatable {

    /// The parameter's label.
    public let label: String?

    /// The parameter's type.
    public let type: QualType

    public init(label: String? = nil, type: QualType) {
      self.label = label
      self.type = type
    }

  }

  /// The function's generic paramters.
  public var genericParams: [TypePlaceholder]

  /// The function's domain.
  public var dom: [Param]

  /// The function's codomain
  public var codom: QualType

  public override func getUnboundPlaceholders() -> Set<TypePlaceholder> {
    return Set(genericParams)
  }

  internal init(
    genericParams: [TypePlaceholder],
    dom: [Param],
    codom: QualType,
    context: CompilerContext,
    info: TypeInfo)
  {
    self.genericParams = genericParams
    self.dom = dom
    self.codom = codom
    super.init(context: context, info: info)
  }

  internal override func equals(to other: TypeBase) -> Bool {
    guard let rhs = other as? FunType
      else { return false }
    return (self.genericParams == rhs.genericParams)
        && (self.dom == rhs.dom)
        && (self.codom == rhs.codom)
  }

  public override func accept<T>(transformer: T) -> T.Result where T: TypeTransformer {
    return transformer.transform(self)
  }

}

public class NominalType: TypeBase {

  /// The type's decl.
  public unowned let decl: NominalTypeDecl

  /// The types's generic parameters.
  public var genericParams: [TypePlaceholder] {
    return decl.genericParams.map { $0.type as! TypePlaceholder }
  }

  public override func getUnboundPlaceholders() -> Set<TypePlaceholder> {
    return Set(genericParams)
  }

  fileprivate init(decl: NominalTypeDecl, context: CompilerContext, info: TypeInfo) {
    self.decl = decl
    super.init(context: context, info: info)
  }

}

public final class InterfaceType: NominalType {

  internal init(decl: InterfaceDecl, context: CompilerContext, info: TypeInfo) {
    super.init(decl: decl, context: context, info: info)
  }

  internal override func equals(to other: TypeBase) -> Bool {
    guard let rhs = other as? InterfaceType
      else { return false }
    return self.decl === rhs.decl
  }

  public override func accept<T>(transformer: T) -> T.Result where T: TypeTransformer {
    return transformer.transform(self)
  }

}

public final class StructType: NominalType {

  internal init(decl: StructDecl, context: CompilerContext, info: TypeInfo) {
    super.init(decl: decl, context: context, info: info)
  }

  internal override func equals(to other: TypeBase) -> Bool {
    guard let rhs = other as? StructType
      else { return false }
    return self.decl === rhs.decl
  }

  public override func accept<T>(transformer: T) -> T.Result where T: TypeTransformer {
    return transformer.transform(self)
  }

}

public final class UnionType: NominalType {

  internal init(decl: UnionDecl, context: CompilerContext, info: TypeInfo) {
    super.init(decl: decl, context: context, info: info)
  }

  internal override func equals(to other: TypeBase) -> Bool {
    guard let rhs = other as? UnionType
      else { return false }
    return self.decl === rhs.decl
  }

  public override func accept<T>(transformer: T) -> T.Result where T: TypeTransformer {
    return transformer.transform(self)
  }

}

// MARK: - Built-ins

/// A built-in type.
public final class BuiltinType: TypeBase {

  /// The type's name.
  public let name: String

  public init(name: String, context: CompilerContext) {
    self.name = name
    super.init(context: context, info: TypeInfo(bits: 0))
  }

  public override func accept<T>(transformer: T) -> T.Result where T: TypeTransformer {
    return transformer.transform(self)
  }

}

/// The type of invalid expressions and signatures.
public final class ErrorType: TypeBase {

  public init(context: CompilerContext) {
    super.init(context: context, info: TypeInfo(bits: 0))
  }

  public override func accept<T>(transformer: T) -> T.Result where T: TypeTransformer {
    return transformer.transform(self)
  }

}
