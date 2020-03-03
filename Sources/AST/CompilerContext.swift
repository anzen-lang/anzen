import SystemKit

import Utils

/// A compiler context holding references to various resources throughout all compilation stages.
public final class CompilerContext {

  public init() {}

  // MARK: - Modules

  /// The current generation number, denoting the number of times new modules have been loaded.
  ///
  /// Some module passes, such as the set of extensions associated with a nominal type, have to
  /// keep track of this generation number to update when they are out of date.
  public var currentGeneration = 0

  /// The modules loaded in the compiler context.
  public var modules: [Module.ID: Module] = [:]

  /// The Anzen built-in module, that defines built-in type declarations.
  public var builtinModule: Module? { modules["__Builtin"] }

  /// The Anzen module, that defines the standard library.
  public var anzenModule: Module? { modules["Anzen"] }

  /// The issues that resulted from the processing the loaded modules.
  public var issues: [Module.ID: Set<Issue>] {
    let allIssues = modules.map({ (id, module) in (id, module.issues) })
    return Dictionary(uniqueKeysWithValues: allIssues)
  }

  // MARK: - Types

  /// Returns the built-in semantic type corresponding the given name.
  public func getBuiltinType(_ name: BuiltinTypeName) -> BuiltinType {
    let decl = builtinModule!.decls.first { ($0 as? BuiltinTypeDecl)?.name == name.rawValue }
    return (decl as! BuiltinTypeDecl).type as! BuiltinType
  }

  /// Anzen's `Nothing` type.
  public private(set) lazy var nothingType: BuiltinType = { [unowned self] in
    return self.getBuiltinType(.nothing)
  }()

  /// Anzen's `Anything` type.
  public private(set) lazy var anythingType: BuiltinType = { [unowned self] in
    return self.getBuiltinType(.anything)
  }()

  /// The error type, representing type errors.
  public private(set) lazy var errorType: ErrorType = { [unowned self] in
    ErrorType(context: self)
  }()

  /// The type of assignment operators.
  public private(set) lazy var assignmentType: QualType = { [unowned self] in
    let anyTy = self.anythingType[.cst]
    let funTy = self.getFunType(
      dom: [FunType.Param(type: anyTy), FunType.Param(type: anyTy)],
      codom: anyTy)
    return funTy[.cst]
  }()

  /// The type uniqueness table.
  private var typeCache: [Int: [TypeBase]] = [:]

  /// Inserts a new element in the type cache and returns it, unless a structually equivalent
  /// instance has already been inserted.
  private func insertType(_ newTy: TypeBase) -> TypeBase {
    var hasher = Hasher()
    newTy.hashContents(into: &hasher)
    let h = hasher.finalize()

    if typeCache[h] == nil {
      typeCache[h] = [newTy]
      return newTy
    } else if let oldTy = typeCache[h]!.first(where: { $0.equals(to: newTy) }) {
      return oldTy
    } else {
      typeCache[h]!.append(newTy)
      return newTy
    }
  }

  /// Returns the kind of the given type.
  public func getTypeKind(of type: TypeBase) -> TypeKind {
    let ty = TypeKind(of: type, context: self, info: type.info)
    return insertType(ty) as! TypeKind
  }

  private var nextTypeVarID = 0

  /// Returns a new type variable.
  public func getTypeVar() -> TypeVar {
    nextTypeVarID += 1
    let info = TypeInfo(props: TypeInfo.hasTypeVar, typeID: nextTypeVarID)
    return TypeVar(context: self, info: info)
  }

  /// Builds (if necessary) and returns the requested type placeholder.
  public func getTypePlaceholder(decl: GenericParamDecl) -> TypePlaceholder {
    let info = TypeInfo(bits: TypeInfo.hasTypePlaceholder)
    let ty = TypePlaceholder(decl: decl, context: self, info: info)
    return insertType(ty) as! TypePlaceholder
  }

  /// Creates (if necessary) and returns a bound generic type.
  public func getBoundGenericType(
    type: TypeBase,
    bindings: [TypePlaceholder: QualType]) -> BoundGenericType
  {
    assert(!bindings.isEmpty)
    let info = bindings.values.reduce(type.info) { result, type in
      result | type.bareType.info
    } | TypeInfo.hasTypePlaceholder

    // Make sure to build a canonical representation of the bounds.
    let ty: BoundGenericType
    if let underlying = type as? BoundGenericType {
      ty = BoundGenericType(
        type: underlying.type,
        bindings: underlying.bindings.merging(bindings) { lhs, _ in lhs },
        context: self,
        info: info)
    } else {
      ty = BoundGenericType(type: type, bindings: bindings, context: self, info: info)
    }

    assert(!(ty.type is BoundGenericType))
    return insertType(ty) as! BoundGenericType
  }

  /// Creates (if necessary) and returns the requested function type.
  public func getFunType(
    placeholders: [TypePlaceholder] = [],
    dom: [FunType.Param],
    codom: QualType) -> FunType
  {
    let info = dom.reduce(codom.bareType.info) { result, param in
      result | param.type.bareType.info
    }

    let ty = FunType(
      placeholders: placeholders,
      dom: dom,
      codom: codom,
      context: self,
      info: info)
    return insertType(ty) as! FunType
  }

  /// Creates (if necessary) and returns the requested interface type.
  public func getInterfaceType(decl: InterfaceDecl) -> InterfaceType {
    let info = decl.genericParams.isEmpty
      ? TypeInfo(bits: 0)
      : TypeInfo(bits: TypeInfo.hasTypePlaceholder)
    let ty = InterfaceType(decl: decl, context: self, info: info)
    return insertType(ty) as! InterfaceType
  }

  /// Creates (if necessary) and returns the requested struct type.
  public func getStructType(decl: StructDecl) -> StructType {
    let info = decl.genericParams.isEmpty
      ? TypeInfo(bits: 0)
      : TypeInfo(bits: TypeInfo.hasTypePlaceholder)
    let ty = StructType(decl: decl, context: self, info: info)
    return insertType(ty) as! StructType
  }

  /// Creates (if necessary) and returns the requested union type.
  public func getUnionType(decl: UnionDecl) -> UnionType {
    let info = decl.genericParams.isEmpty
      ? TypeInfo(bits: 0)
      : TypeInfo(bits: TypeInfo.hasTypePlaceholder)
    let ty = UnionType(decl: decl, context: self, info: info)
    return insertType(ty) as! UnionType
  }

  /// Returns all types conforming to the given one.
  public func getTypesConforming(to type: TypeBase, transitively: Bool = true) -> Set<TypeBase> {
    assert(!(type is TypeVar), "cannot compute the conformance set of type variable")
    assert(type != anythingType, "all types conform to `Anything`")

    switch type {
    case let ty as UnionType:
      guard let body = (ty.decl as! UnionDecl).body
        else { return [] }

      let conformingTypes = body.stmts.compactMap { stmt -> TypeBase? in
        switch stmt {
        case let decl as UnionTypeCaseDecl:
          return decl.nestedDecl.type
        case let decl as UnionAliasCaseDecl:
          return decl.referredDecl?.type
        default:
          return nil
        }
      }

      if transitively {
        return conformingTypes.reduce(Set(conformingTypes)) { (result, type) in
          result.union(getTypesConforming(to: type))
        }
      } else {
        return Set(conformingTypes)
      }

    case is InterfaceType:
      // FIXME: Implement me
      return []

    default:
      return []
    }
  }

}
