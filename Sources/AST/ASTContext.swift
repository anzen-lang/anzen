import Utils
import SystemKit

/// Class that holds an AST's metadata.
public final class ASTContext {

  public init(anzenPath: Path, moduleLoader: ModuleLoader) {
    self.anzenPath = anzenPath
    self.moduleLoader = moduleLoader

    // Load core module.
    _ = getModule(moduleID: .builtin)
    _ = getModule(moduleID: .stdlib)
  }

  /// The path to Anzen's core modules.
  public let anzenPath: Path

  public func add(error: ASTError) {
    errors.append(error)
  }

  public func add(error: Any, on node: Node) {
    errors.append(ASTError(cause: error, node: node))
  }

  public func add(constraint: Constraint) {
    typeConstraints.append(constraint)
  }

  // MARK: Modules

  /// Returns a module given its identifier, loading it if necessary.
  public func getModule(moduleID: ModuleIdentifier) -> ModuleDecl? {
    if let module = loadedModules[moduleID] {
      return module
    } else if let module = moduleLoader.load(moduleID, in: self) {
      loadedModules[moduleID] = module
      return module
    } else {
      return nil
    }
  }

  /// The module loader.
  private let moduleLoader: ModuleLoader
  /// The loaded already loaded in the context.
  public private(set) var loadedModules: [ModuleIdentifier: ModuleDecl] = [:]

  /// The built-in module.
  public var builtinModule: ModuleDecl { return loadedModules[.builtin]! }
  /// The standard library module.
  public var stdlibModule: ModuleDecl { return loadedModules[.stdlib]! }

  public var declarations: [Symbol: NamedDecl] {
    return loadedModules.values.reduce([:]) { (res, module) in
      res.merging(module.declarations) { _, rhs in rhs }
    }
  }

  // MARK: Types

  /// Retrieves or create a function type.
  public func getFunctionType(
    from domain: [Parameter], to codomain: TypeBase, placeholders: [PlaceholderType] = [])
    -> FunctionType
  {
    if let type = functionTypes.first(where: {
      return ($0.domain == domain)
        && ($0.codomain == codomain)
        && ($0.placeholders == placeholders)
    }) {
      return type
    }
    let type = FunctionType(domain: domain, codomain: codomain, placeholders: placeholders)
    functionTypes.append(type)
    return type
  }

  /// Retrieves or create a placeholder type.
  public func getPlaceholderType(for symbol: Symbol) -> PlaceholderType {
    if let ty = placeholderTypes[symbol] {
      return ty
    }
    let ty = PlaceholderType(name: symbol.name)
    placeholderTypes[symbol] = ty
    return ty
  }

  /// Retrieves or create a struct type.
  public func getStructType(
    for decl: NominalTypeDecl,
    memberScope: Scope,
    isBuiltin: Bool) -> StructType
  {
    return getNominalType(for: decl, memberScope: memberScope, isBuiltin: isBuiltin)
  }

  /// Retrieves or create a nominal type.
  public func getNominalType<Ty>(
    for decl: NominalTypeDecl,
    memberScope: Scope,
    isBuiltin: Bool) -> Ty
    where Ty: NominalType
  {
    if let nominal = nominalTypes[decl.symbol!] {
      let ty = nominal as? Ty
      assert(ty != nil, "\(nominal) is not a \(Ty.self)")
      return ty!
    }
    let ty = Ty(decl: decl, memberScope: memberScope, isBuiltin: isBuiltin)
    nominalTypes[decl.symbol!] = ty
    return ty
  }

  /// The nominal types in the context.
  private var nominalTypes: [Symbol: NominalType] = [:]
  /// The placeholder types in the context.
  private var placeholderTypes: [Symbol: PlaceholderType] = [:]
  /// The function types in the context.
  private var functionTypes: [FunctionType] = []
  /// The type constraints that haven't been solved yet.
  public var typeConstraints: [Constraint] = []

  // MARK: Built-ins

  /// Anzen's `Anything` type.
  public var anythingType: AnythingType { return builtinTypes["Anything"] as! AnythingType }
  /// Anzen's `Nothing` type.
  public var nothingType: NothingType { return builtinTypes["Nothing"] as! NothingType }

  /// The built-in types.
  public lazy var builtinTypes: [String: TypeBase] = {
    guard let module = getModule(moduleID: .builtin)
      else { fatalError("unable to load built-in module") }
    return Dictionary(
      uniqueKeysWithValues: module.typeDeclarations.map({ (name, declaration) in
        let metatype = declaration.type as! Metatype
        return (name, metatype.type)
      }))
  }()

  // MARK: Diagnostics

  /// The list of errors encountered during the processing of the AST.
  public var errors: [ASTError] = []

}
