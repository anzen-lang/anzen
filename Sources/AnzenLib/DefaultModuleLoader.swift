import AST
import Parser
import Utils
import Sema
import SystemKit

/// The default module loader.
public final class DefaultModuleLoader: ModuleLoader {

  public struct DebugConfig {

    public init() {}

    public var showRawAST: Bool = false
    public var showScopedAST: Bool = false
    public var showTypedAST: Bool = false
    public var showTypeConstraints: Bool = false

  }

  public init(logger: Logger? = nil, config: DebugConfig = DebugConfig()) {
    self.logger = logger
    self.config = config
  }

  /// The loader's logger.
  public let logger: Logger?
  /// The loader's debug config (for logging).
  public let config: DebugConfig

  public func load(_ moduleID: ModuleIdentifier, in context: ASTContext) -> ModuleDecl? {

    // ------- //
    // Parsing //
    // ------- //

    let file = locate(moduleID: moduleID, in: context)
    var module: ModuleDecl
    do {
      module = try Parser(source: file).parse()
      module.id = moduleID
    } catch {
      logger?.error(error)
      return nil
    }

    if config.showRawAST && (moduleID != .builtin) && (moduleID != .stdlib) {
      let buffer = StringBuffer()
      try! ASTDumper(to: buffer).visit(module)
      logger?.debug(buffer.value)
    }

    // ------- //
    // Scoping //
    // ------- //

    // Note that semantic analysis passes do not raise with errors if something goes wrong, but
    // rather add the errors encountered in the AST context. This is why we run the visitors
    // unsafely, and check if there's anything in `context.errors` after each pass.

    // Symbol creation.
    let symbolCreator = SymbolCreator(context: context)
    try! symbolCreator.visit(module)
    guard context.errors.isEmpty else {
      logger?.errors(context.errors.sorted(by: <))
      return nil
    }

    // Name binding.
    let nameBinder = NameBinder(context: context)
    try! nameBinder.visit(module)
    guard context.errors.isEmpty else {
      logger?.errors(context.errors.sorted(by: <))
      return nil
    }

    if config.showScopedAST && (moduleID != .builtin) && (moduleID != .stdlib) {
      let buffer = StringBuffer()
      try! ASTDumper(to: buffer).visit(module)
      logger?.debug(buffer.value)
    }

    // -------------- //
    // Type Inference //
    // -------------- //

    // Type constraints creation.
    let constraintCreator = ConstraintCreator(context: context)
    try! constraintCreator.visit(module)
    guard context.errors.isEmpty else {
      logger?.errors(context.errors.sorted(by: <))
      return nil
    }

    if config.showTypeConstraints && (moduleID != .builtin) && (moduleID != .stdlib) {
      var buffer = ""
      for constraint in context.typeConstraints {
        constraint.dump(to: &buffer)
      }
      logger?.debug(buffer)
    }

    // Solve the type constraints.
    var solver = ConstraintSolver(constraints: context.typeConstraints, in: context)
    let result = solver.solve()

    // --------------- //
    // Static Dispatch //
    // --------------- //

    // Apply the solution of the solver (if any) and dispatch identifiers to their symbol.
    switch result {
    case .success(let solution):
      let dispatcher = Dispatcher(context: context, solution: solution)
      module = try! dispatcher.transform(module) as! ModuleDecl
      guard context.errors.isEmpty else {
        logger?.errors(context.errors.sorted(by: <))
        return nil
      }

    case .failure(let errors):
      logger?.errors(errors)
      return nil
    }

    // Identify closure captures.
    let captureAnalyzer = CaptureAnalyzer()
    try! captureAnalyzer.visit(module)

    if config.showTypedAST && (moduleID != .builtin) && (moduleID != .stdlib) {
      let buffer = StringBuffer()
      try! ASTDumper(to: buffer).visit(module)
      logger?.debug(buffer.value)
    }

    context.typeConstraints.removeAll()
    return module
  }

  public func locate(moduleID: ModuleIdentifier, in context: ASTContext) -> TextFile {
    // Determine the filepath of the module.
    let modulepath: Path
    switch moduleID {
    case .builtin: modulepath = context.anzenPath.joined(with: "builtin.anzen")
    case .stdlib: modulepath = context.anzenPath.joined(with: "stdlib.anzen")
    case .local(let path): modulepath = path
    }

    return TextFile(path: modulepath)
  }

}

struct LoaderError: Error {

}
