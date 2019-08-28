import Utils
import SystemKit

/// A compiler context holding references to various resources throughout all compilation stages.
public final class CompilerContext {

  /// The path to Anzen's core modules.
  public let anzenPath: Path

  /// The context's module loader.
  public let loader: ModuleLoader

  public init(anzenPath: Path, loader: ModuleLoader) throws {
    self.anzenPath = anzenPath
    self.loader = loader

    // Load the core modules.
    builtinModule = Module(id: "__Builtin", generationNumber: 0, state: .typeChecked)
    for name in BuiltinTypeName.allCases {
      let decl = BuiltinTypeDecl(name: name.rawValue, module: builtinModule)
      decl.type = BuiltinType(decl: decl, context: self)
      decl.declContext = builtinModule

      builtinModule.decls.append(decl)
    }
    modules["__Builtin"] = builtinModule

    let corePath = anzenPath.joined(with: "Core")
    try loadModule(fromDirectory: corePath, withID: "Anzen")
  }

  // MARK: - Modules

  /// The current generation number, denoting the number of times new modules have been loaded.
  ///
  /// Some module passes, such as the set of extensions associated with a nominal type, have to
  /// keep track of this generation number to update when they are out of date.
  public private(set) var currentGeneration = 0

  /// The modules loaded in the compiler context.
  public private(set) var modules: [Module.ID: Module] = [:]

  /// The Anzen built-in module, that defines built-in type declarations.
  public var builtinModule: Module!

  /// The Anzen module, that defines the standard library.
  public var anzenModule: Module { return modules["Anzen"]! }

  /// The issues that resulted from the processing the loaded modules.
  public var issues: [Module.ID: Set<Issue>] {
    let allIssues = modules.map({ (id, module) in (id, module.issues) })
    return Dictionary(uniqueKeysWithValues: allIssues)
  }

  /// Load a module from a directory.
  @discardableResult
  public func loadModule(fromDirectory dir: Path, withID id: Module.ID? = nil) throws
    -> (module: Module, loaded: Bool)
  {
    let moduleID = id ?? dir.components.last.map(String.init) ?? "unnamed"
    if let module = modules[moduleID] {
      return (module, false)
    }

    currentGeneration += 1
    let module = Module(id: moduleID, generationNumber: currentGeneration)
    modules[moduleID] = module
    try loader.load(module: module, fromDirectory: dir, in: self)
    return (module, true)
  }

  /// Loads a single translation unit as a module from a text buffer.
  @discardableResult
  public func loadModule(fromText buffer: TextInputBuffer, withID id: Module.ID) throws
    -> (module: Module, loaded: Bool)
  {
    if let module = modules[id] {
      return (module, false)
    }

    currentGeneration += 1
    let module = Module(id: id, generationNumber: currentGeneration)
    modules[id] = module
    try loader.load(module: module, fromText: buffer, in: self)
    return (module, true)
  }

  // MARK: - Types

  /// An enumeration of the built-in types' names.
  public enum BuiltinTypeName: String, CaseIterable {

    case nothing = "Nothing"
    case anything = "Anything"
    case bool = "Bool"
    case int = "Int"
    case float = "Float"
    case string = "String"

    public static func contains(_ name: String) -> Bool {
      return allCases.contains { $0.rawValue == name }
    }

  }

  /// Returns the built-in semantic type corresponding the given name.
  public func getBuiltinType(_ name: BuiltinTypeName) -> BuiltinType {
    let decl = anzenModule.decls.first { ($0 as? BuiltinTypeDecl)?.name == name.rawValue }
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
    let info = type.info | TypeInfo.hasTypePlaceholder

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
  public func getTypesConforming(to type: TypeBase) -> [TypeBase] {
    assert(type != anythingType, "all types conform to `Anything`")

    // TODO: Implement me
    return []
  }

}
