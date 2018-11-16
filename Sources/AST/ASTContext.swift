import Utils
import SystemKit

/// Cass that holds metadata to be associated with an AST.
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

  /// Retrieves or create a struct type.
  public func getStructType(for symbol: Symbol, memberScope: Scope) -> StructType {
    return getType(for: symbol, memberScope: memberScope)
  }

  /// Retrieves or create a placeholder type.
  public func getPlaceholderType(for symbol: Symbol) -> PlaceholderType {
    return getType(for: symbol, memberScope: nil)
  }

  /// Retrieves or create a nominal type.
  public func getType<Ty>(for symbol: Symbol, memberScope: Scope?) -> Ty where Ty: NominalType {
    if let nominal = nominalTypes[symbol] {
      let ty = nominal as? Ty
      assert(ty != nil, "\(nominal) is not a \(Ty.self)")
      return ty!
    }
    let ty = Ty(name: symbol.name, memberScope: memberScope)
    nominalTypes[symbol] = ty
    return ty
  }

  /// The nominal types in the context.
  private var nominalTypes: [Symbol: NominalType] = [:]
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
      uniqueKeysWithValues: module.typeDecls.map({
        let meta = ($0.type as! Metatype)
        return ($0.name, meta.type)
      }))
  }()

  // MARK: Diagnostics

  /// The list of errors encountered during the processing of the AST.
  public var errors: [ASTError] = []

}
