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

  fileprivate func subst(_ substitutions: [TypePlaceholder: QualType]) -> QualType {
    if let ty = bareType as? TypePlaceholder {
      return substitutions[ty] ?? self
    } else {
      return QualType(bareType: bareType.subst(substitutions), quals: quals)
    }
  }

}

/// A structure that stores various information about a type.
public struct TypeInfo {

  public let bits: Int

  public init(bits: Int) {
    self.bits = bits
  }

  public init(props: Int, typeID: Int) {
    // Stores the type ID in the 16 most significant bits.
    let n = Int.bitWidth - 16
    self.bits = (typeID << n) | props
  }

  /// The type's identifier, if any.
  public var typeID: Int {
    let n = Int.bitWidth - 16
    let m = ((1 << 16) - 1) << n
    return (bits & m) >> n
  }

  /// Returns whether the given properties hold.
  public func check(_ props: Int) -> Bool {
    return (bits & props) != 0
  }

  /// Indicates a type in which one or more type variables occur.
  public static let hasTypeVar = 1 << 0

  /// Indicates a type in which one or more generic type placeholder occur.
  public static let hasTypePlaceholder = 1 << 1

  static func | (lhs: TypeInfo, rhs: TypeInfo) -> TypeInfo {
    return TypeInfo(bits: lhs.bits | rhs.bits)
  }

  static func | (lhs: TypeInfo, rhs: Int) -> TypeInfo {
    return TypeInfo(bits: lhs.bits | rhs)
  }

}

/// A semantic type.
public class TypeBase: Hashable {

  /// The compiler context.
  public final unowned let context: CompilerContext

  /// Various information about this type.
  public final let info: TypeInfo

  /// The type's declaration (if any).
  public fileprivate(set) final weak var decl: TypeDecl?

  /// Whether this type can be opened.
  public final var canBeOpened: Bool {
    guard info.check(TypeInfo.hasTypePlaceholder)
      else { return false }

    switch self {
    case is FunType, is NominalType, is BuiltinType:
      return true
    case let kind as TypeKind:
      return kind.canBeOpened
    default:
      return false
    }
  }

  /// The type's kind.
  public final var kind: TypeKind { return context.getTypeKind(of: self) }

  /// The type qualified with the `@cst` qualifier.
  public final var cst: QualType { return QualType(bareType: self, quals: [.cst]) }

  /// The type qualified with the `@mut` qualifier.
  public final var mut: QualType { return QualType(bareType: self, quals: [.mut]) }

  /// Returns the set of unbound generic placeholders occuring in the type.
  public func getUnboundPlaceholders() -> Set<TypePlaceholder> {
    return []
  }

  fileprivate func subst(_ substitutions: [TypePlaceholder: QualType]) -> TypeBase {
    return self
  }

  internal init(context: CompilerContext, info: TypeInfo) {
    self.context = context
    self.info = info
  }

  public static func == (lhs: TypeBase, rhs: TypeBase) -> Bool {
    return lhs === rhs
  }

  public final func hash(into hasher: inout Hasher) {
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
    fatalError("call to abstract method 'hashContents(into:)'")
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

  fileprivate override func subst(_ substitutions: [TypePlaceholder: QualType]) -> TypeBase {
    guard info.check(TypeInfo.hasTypePlaceholder)
      else { return self }
    return type.subst(substitutions).kind
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

  internal override func hashContents(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(type))
  }

  public override func accept<T>(transformer: T) -> T.Result where T: TypeTransformer {
    return transformer.transform(self)
  }

}

/// A type variable used during type inference.
public final class TypeVar: TypeBase {

  internal override func hashContents(into hasher: inout Hasher) {
    hasher.combine(info.typeID)
  }

}

/// A type placeholder in a generic type.
public final class TypePlaceholder: TypeBase {

  /// The type's name.
  public var name: String { return (decl as! GenericParamDecl).name }

  public override func getUnboundPlaceholders() -> Set<TypePlaceholder> {
    return Set([self])
  }

  fileprivate override func subst(_ substitutions: [TypePlaceholder: QualType]) -> TypeBase {
    fatalError("subst(:) should not be called on type placeholders")
  }

  internal init(decl: GenericParamDecl, context: CompilerContext, info: TypeInfo) {
    super.init(context: context, info: info)
    self.decl = decl
  }

  internal override func equals(to other: TypeBase) -> Bool {
    guard let rhs = other as? TypePlaceholder
      else { return false }
    return self.decl === rhs.decl
  }

  internal override func hashContents(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(decl!))
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
  public let bindings: [TypePlaceholder: QualType]

  public override func getUnboundPlaceholders() -> Set<TypePlaceholder> {
    return type.getUnboundPlaceholders().subtracting(bindings.keys)
  }

  fileprivate override func subst(_ substitutions: [TypePlaceholder: QualType]) -> TypeBase {
    let newBindings = Dictionary(
      uniqueKeysWithValues: bindings.map { ($0, substitutions[$0] ?? $1) })
    return context.getBoundGenericType(type: type, bindings: newBindings)
  }

  internal init(
    type: TypeBase,
    bindings: [TypePlaceholder: QualType],
    context: CompilerContext,
    info: TypeInfo)
  {
    self.type = type
    self.bindings = bindings

    super.init(context: context, info: info)
    self.decl = type.decl
  }

  internal override func equals(to other: TypeBase) -> Bool {
    guard let rhs = other as? BoundGenericType else { return false }
    return (self.type === rhs.type)
        && (self.bindings == rhs.bindings)
  }

  internal override func hashContents(into hasher: inout Hasher) {
    hasher.combine(type)
    hasher.combine(bindings)
  }

  public override func accept<T>(transformer: T) -> T.Result where T: TypeTransformer {
    return transformer.transform(self)
  }

}

public final class FunType: TypeBase {

  /// A function type's parameter.
  public struct Param: Hashable {

    /// The parameter's label.
    public let label: String?

    /// The parameter's type.
    public let type: QualType

    public init(label: String? = nil, type: QualType) {
      self.label = label
      self.type = type
    }

  }

  /// The function's generic type placeholders.
  public var placeholders: [TypePlaceholder]

  /// The function's domain.
  public var dom: [Param]

  /// The function's codomain
  public var codom: QualType

  public override func getUnboundPlaceholders() -> Set<TypePlaceholder> {
    var result = Set(placeholders)
    for param in dom {
      result.formUnion(param.type.bareType.getUnboundPlaceholders())
    }
    result.formUnion(codom.bareType.getUnboundPlaceholders())
    return result
  }

  public override func subst(_ substitutions: [TypePlaceholder: QualType]) -> TypeBase {
    let newDom = dom.map { param -> Param in
      return Param(label: param.label, type: param.type.subst(substitutions))
    }
    let newCodom = codom.subst(substitutions)
    let newPlaceholders = placeholders.filter { substitutions[$0] == nil }

    return context.getFunType(placeholders: newPlaceholders, dom: newDom, codom: newCodom)
  }

  internal init(
    placeholders: [TypePlaceholder],
    dom: [Param],
    codom: QualType,
    context: CompilerContext,
    info: TypeInfo)
  {
    self.placeholders = placeholders
    self.dom = dom
    self.codom = codom
    super.init(context: context, info: info)
  }

  internal override func equals(to other: TypeBase) -> Bool {
    guard let rhs = other as? FunType
      else { return false }
    return (self.placeholders == rhs.placeholders)
        && (self.dom == rhs.dom)
        && (self.codom == rhs.codom)
  }

  internal override func hashContents(into hasher: inout Hasher) {
    hasher.combine(placeholders)
    hasher.combine(dom)
    hasher.combine(codom)
  }

  public override func accept<T>(transformer: T) -> T.Result where T: TypeTransformer {
    return transformer.transform(self)
  }

}

public class NominalType: TypeBase {

  /// The type's name.
  public var name: String {
    return (decl as! NominalOrBuiltinTypeDecl).name
  }

  /// The type's geneirc parameters.
  public var placeholders: [TypePlaceholder] {
    return (decl as! NominalOrBuiltinTypeDecl).genericParams.map { $0.type as! TypePlaceholder }
  }

  public override func getUnboundPlaceholders() -> Set<TypePlaceholder> {
    return Set(placeholders)
  }

  public override func subst(_ substitutions: [TypePlaceholder: QualType]) -> TypeBase {
    let keys = Set(placeholders)
    let bindings = substitutions.filter({ keys.contains($0.key) })
    return bindings.isEmpty
      ? self
      : context.getBoundGenericType(type: self, bindings: bindings)
  }

  fileprivate init(decl: NominalOrBuiltinTypeDecl, context: CompilerContext, info: TypeInfo) {
    super.init(context: context, info: info)
    self.decl = decl
  }

  internal override func hashContents(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(decl!))
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
  public var name: String {
    return (decl as! NominalOrBuiltinTypeDecl).name
  }

  /// The type's geneirc parameters.
  public var placeholders: [TypePlaceholder] {
    return (decl as! NominalOrBuiltinTypeDecl).genericParams.map { $0.type as! TypePlaceholder }
  }

  public init(decl: BuiltinTypeDecl, context: CompilerContext) {
    super.init(context: context, info: TypeInfo(bits: 0))
    self.decl = decl
  }

  public override func subst(_ substitutions: [TypePlaceholder: QualType]) -> TypeBase {
    let keys = Set(placeholders)
    let bindings = substitutions.filter({ keys.contains($0.key) })
    return bindings.isEmpty
      ? self
      : context.getBoundGenericType(type: self, bindings: bindings)
  }

  internal override func hashContents(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(decl!))
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

  internal override func hashContents(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }

  public override func accept<T>(transformer: T) -> T.Result where T: TypeTransformer {
    return transformer.transform(self)
  }

}
