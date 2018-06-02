import AST
import Parser
import Utils

/// Protocol for module loaders.
public protocol ModuleLoader {

  func load(_ moduleID: ModuleIdentifier, in context: ASTContext) throws -> ModuleDecl

}

/// An enumeration of the verbosity levels of a module loader.
public enum ModuleLoaderVerbosity: Int, Comparable {

  /// Don't output anything.
  case normal = 0
  /// Outputs various debug regarding the loading process of a module.
  case verbose
  /// Outputs all debug information, including the typing constraints of the semantic analysis.
  case debug

  public static func < (lhs: ModuleLoaderVerbosity, rhs: ModuleLoaderVerbosity) -> Bool {
    return lhs.rawValue < rhs.rawValue
  }

}

/// The default module loader.
open class LocalModuleLoader: ModuleLoader {

  public enum LoadingError: Error {

    case moduleNotFound(moduleID: ModuleIdentifier)
    case semanticAnalysisFailed(errors: [Any])

  }

  public init(searchPaths: [String], verbosity: ModuleLoaderVerbosity = .normal) {
    self.searchPaths = searchPaths
    self.verbosity = verbosity
  }

  /// The locations in which the loader shall try to locate modules.
  let searchPaths: [String]
  /// The verbosity level of the loader.
  let verbosity: ModuleLoaderVerbosity

  public func load(_ moduleID: ModuleIdentifier, in context: ASTContext) throws -> ModuleDecl {
    // Start the stopwatch.
    var stopwatch = Stopwatch()

    // Locate and parse the module.
    guard let file = locate(moduleID: moduleID)
      else { throw LoadingError.moduleNotFound(moduleID: moduleID) }
    let source = ASTSource.file(stream: file)
    let module = try Parser(source: source).parse()
    module.id = moduleID
    let parseTime = stopwatch.elapsed

    // Create the type constraints.
    stopwatch.reset()
    var passes: [SAPass] = [
      SymbolCreator(context: context),
      NameBinder(context: context),
      ConstraintCreator(context: context),
    ]
    for i in 0 ..< passes.count {
      try passes[i].visit(module)
    }
    let constraintCreationTime = stopwatch.elapsed

    // Solve the type constraints.
    stopwatch.reset()
    var solver = ConstraintSolver(constraints: context.typeConstraints, in: context)
    let result = solver.solve()
    let solvingTime = stopwatch.elapsed
    context.typeConstraints.removeAll()

    // Apply the solution of the solver (if any) and dispatch identifiers to their symbol.
    stopwatch.reset()
    switch result {
    case .success(let solution, _):
      var applier = TypeApplier(context: context, solution: solution)
      try applier.visit(module)

    case .failure(let errors):
      throw LoadingError.semanticAnalysisFailed(errors: errors)
    }
    let dispatchTime = stopwatch.elapsed

    // Output verbose informations.
    if verbosity >= .verbose {
      Console.err.print("Loading module '\(moduleID.qualifiedName)' ...", in: .bold)
      Console.err.print("- Parsed in \(parseTime.humanFormat)")
      Console.err.print("- Created type constraints in \(constraintCreationTime.humanFormat)")
      if verbosity >= .debug {
        for constraint in context.typeConstraints {
          constraint.prettyPrint(in: Console.err, level: 2)
        }
      }
      Console.err.print("- Solved type constraints in \(solvingTime.humanFormat)")
      Console.err.print("- Dispatched symbols in \(dispatchTime.humanFormat)")
      Console.err.print()
    }

    return module
  }

  public func locate(moduleID: ModuleIdentifier) -> TextFileStream? {
    // Determine the filename of the module.
    let basename: String
    switch moduleID {
    case .builtin:
      basename = "builtin.anzen"
    case .stdlib:
      basename = "stdlib.anzen"
    case .local(name: let name):
      basename = "\(name).anzen"
    }

    for directory in searchPaths {
      let filename = directory + basename
      if TextFileStream.exists(filename: filename) {
        return TextFileStream(filename: filename)
      }
    }
    return nil
  }

}
