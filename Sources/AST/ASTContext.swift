import Utils

/// Cass that holds metadata to be associated with an AST.
public final class ASTContext {

  // FIXME: Module loaders shouldn't throw error, but instead add them to the AST context, so that
  // we can proceed with the compilation process in a "degraded" mode.
  public typealias ModuleLoader = (ModuleIdentifier, ASTContext) throws -> ModuleDecl

  public init(loadModule: @escaping ModuleLoader) {
    self.loadModule = loadModule
  }

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
  public func getModule(moduleID: ModuleIdentifier) throws -> ModuleDecl {
    if let module = loadedModules[moduleID] {
      return module
    }
    let module = try loadModule(moduleID, self)
    loadedModules[moduleID] = module
    return module
  }

  /// The module loader.
  public let loadModule: ModuleLoader
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
  public func getStructType(for symbol: Symbol) -> StructType {
    return getType(for: symbol)
  }

  /// Retrieves or create a placeholder type.
  public func getPlaceholderType(for symbol: Symbol) -> PlaceholderType {
    return getType(for: symbol)
  }

  /// Retrieves or create a nominal type.
  public func getType<Ty>(for symbol: Symbol) -> Ty where Ty: NominalType {
    if let nominal = nominalTypes[symbol] {
      let ty = nominal as? Ty
      assert(ty != nil, "\(nominal) is not a \(Ty.self)")
      return ty!
    }
    let ty = Ty(name: symbol.name)
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

  /// The built-in scope.
  public lazy var builtinScope: Scope = loadScope(for: .builtin)
  /// The stdlib scope.
  public lazy var stdlibScope: Scope = loadScope(for: .stdlib)

  /// The built-in types.
  public lazy var builtinTypes: [String: NominalType] = {
    do {
      let module = try getModule(moduleID: .builtin)
      return Dictionary(
        uniqueKeysWithValues: module.typeDecls.map({
          let meta = ($0.type as! Metatype)
          let type = meta.type as! NominalType
          return ($0.name, type)
        }))
    } catch {
      fatalError("unable to load built-in module: \(error)")
    }
  }()

  private func loadScope(for moduleID: ModuleIdentifier) -> Scope {
    do {
      let module = try getModule(moduleID: moduleID)
      return module.innerScope!
    } catch {
      fatalError("unable to load \(moduleID): \(error)")
    }
  }

  // MARK: Diagnostics

  /// The list of errors encountered during the processing of the AST.
  public var errors: [ASTError] = []

}

/// An error associated with an AST node.
public struct ASTError {

  public init(cause: Any, node: Node) {
    self.cause = cause
    self.node = node
  }

  public let cause: Any
  public let node: Node

}
