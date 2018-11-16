import AST
import Parser
import Utils
import Sema
import SystemKit

/// The default module loader.
public final class DefaultModuleLoader: ModuleLoader {

  public init(logger: Logger? = nil) {
    self.logger = logger
  }

  /// The loader's logger.
  public let logger: Logger?

  public func load(_ moduleID: ModuleIdentifier, in context: ASTContext) -> ModuleDecl? {
    logger?.verbose("Loading module '\(moduleID.qualifiedName)'".styled("bold"))
    var stopwatch = Stopwatch()

    // ------- //
    // Parsing //
    // ------- //

    let file = locate(moduleID: moduleID, in: context)
    let module: ModuleDecl
    do {
      module = try Parser(source: file).parse()
      module.id = moduleID
    } catch {
      logger?.log(error: error)
      return nil
    }

    let parseTime = stopwatch.elapsed
    logger?.verbose("Parsed in \(parseTime.humanFormat)")

    // ------- //
    // Scoping //
    // ------- //

    // Note that semantic analysis passes do not raise with an error is something goes wrong, but
    // rather add the errors they encountered in the AST context. This is why we run the visitors
    // unsafely with `!`, but check if there's anything in `context.errors` after each pass.

    stopwatch.reset()

    // Symbol creation.
    let symbolCreator = SymbolCreator(context: context)
    try! symbolCreator.visit(module)
    guard context.errors.isEmpty else {
      logger?.log(astErrors: context.errors)
      return nil
    }

    // Name binding.
    let nameBinder = NameBinder(context: context)
    try! nameBinder.visit(module)
    guard context.errors.isEmpty else {
      logger?.log(astErrors: context.errors)
      return nil
    }

    // -------------- //
    // Type Inference //
    // -------------- //

    // Type constraints creation.
    let constraintCreator = ConstraintCreator(context: context)
    try! constraintCreator.visit(module)
    guard context.errors.isEmpty else {
      logger?.log(astErrors: context.errors)
      return nil
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
      try! dispatcher.visit(module)
      guard context.errors.isEmpty else {
        logger?.log(astErrors: context.errors)
        return nil
      }

    case .failure(let errors):
      for error in errors {
        logger?.log(unsolvableConstraint: error.constraint, causedBy: error.cause)
      }
      return nil
    }

    let semanticAnalysisTime = stopwatch.elapsed
    logger?.verbose("Semantic analysis completed in \(semanticAnalysisTime.humanFormat)\n")

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
