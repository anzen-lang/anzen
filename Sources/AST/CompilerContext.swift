import Utils
import SystemKit

/// A compiler context holding references to various resources throughout all compilation stages.
public final class CompilerContext {

  /// The path to Anzen's core modules.
  public let anzenPath: Path

  public init?(anzenPath: Path) {
    self.anzenPath = anzenPath

    // Load the core modules.
    guard let (anzenModule, _) = loadModule(fromDirectory: anzenPath, withID: "Anzen")
      else { return nil }
    self.anzenModule = anzenModule
  }

  // MARK: - Modules

  /// The core module.
  public var anzenModule: Module!
  /// The modules loaded in the compiler context.
  public private(set) var modules: [Module.ID: Module] = [:]
  /// The issues that resulted from the processing the loaded modules.
  public var issues: [Module.ID: Set<Issue>] {
    let allIssues = modules.map({ (id, module) in (id, module.issues) })
    return Dictionary(uniqueKeysWithValues: allIssues)
  }

  /// Load a module from a directory.
  ///
  /// This method will merge fetch source files (i.e. `.anzen` files) **directly** under the given
  /// directory, merge them in a single compilation unit and compile them as a module.
  @discardableResult
  public func loadModule(fromDirectory: Path, withID moduleID: Module.ID? = nil)
    -> (module: Module, loaded: Bool)?
  {
    return nil
  }

  /// Loads a single translation unit as a module from a text buffer.
  @discardableResult
  public func loadModule(fromText: TextInputBuffer, withID moduleID: Module.ID)
    -> (module: Module, loaded: Bool)?
  {
    return nil
  }

  // MARK: - Types

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
    let ty = TypeKind(of: type, in: self)
    return insertType(ty) as! TypeKind
  }

  /// Returns a new type variable.
  public func getTypeVar(quals: TypeQualSet = []) -> TypeVar {
    return TypeVar(quals: quals, context: self)
  }

  /// Builds (if necessary) and returns the requested type placeholder.
  public func getTypePlaceholder(quals: TypeQualSet, decl: GenericParamDecl) -> TypePlaceholder {
    let ty = TypePlaceholder(quals: quals, decl: decl, in: self)
    return insertType(ty) as! TypePlaceholder
  }

  /// Creates (if necessary) and returns a bound generic type.
  public func getBoundGenericType(
    type: TypeBase,
    bindings: [TypePlaceholder: TypeBase]) -> BoundGenericType
  {
    let ty = BoundGenericType(type: type, bindings: bindings, in: self)
    return insertType(ty) as! BoundGenericType
  }

  /// Creates (if necessary) and returns the requested function type.
  public func getFunType(
    quals: TypeQualSet,
    genericParams: [TypePlaceholder],
    dom: [FunType.Param],
    codom: TypeBase) -> FunType
  {
    let ty = FunType(quals: quals, genericParams: genericParams, dom: dom, codom: codom, in: self)
    return insertType(ty) as! FunType
  }

  /// Creates (if necessary) and returns the requested struct type.
  public func getStructType(quals: TypeQualSet, decl: StructDecl) -> StructType {
    let ty = StructType(quals: quals, decl: decl, in: self)
    return insertType(ty) as! StructType
  }

  /// Creates (if necessary) and returns the requested union type.
  public func getUnionType(quals: TypeQualSet, decl: UnionDecl) -> UnionType {
    let ty = UnionType(quals: quals, decl: decl, in: self)
    return insertType(ty) as! UnionType
  }

}
