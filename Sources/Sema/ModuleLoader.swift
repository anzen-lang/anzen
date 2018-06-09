import AST
import Parser
import Utils
import SystemKit

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
open class DefaultModuleLoader: ModuleLoader {

  public init(verbosity: ModuleLoaderVerbosity = .normal) {
    self.verbosity = verbosity
  }

  /// The verbosity level of the loader.
  let verbosity: ModuleLoaderVerbosity

  public func load(_ moduleID: ModuleIdentifier, in context: ASTContext) throws -> ModuleDecl {
    // Start the stopwatch.
    var stopwatch = Stopwatch()

    // Locate and parse the module.
    let file = locate(moduleID: moduleID, in: context)
    let module = try Parser(source: file).parse()
    module.id = moduleID
    let parseTime = stopwatch.elapsed

    // Create the type constraints.
    stopwatch.reset()
    let passes: [SAPass] = [
      SymbolCreator(context: context),
      NameBinder(context: context),
      ConstraintCreator(context: context),
    ]
    for pass in passes {
      try pass.visit(module)
    }
    let constraintCreationTime = stopwatch.elapsed

    // Solve the type constraints.
    stopwatch.reset()
    var solver = ConstraintSolver(constraints: context.typeConstraints, in: context)
    let result = solver.solve()
    let solvingTime = stopwatch.elapsed

    // Apply the solution of the solver (if any) and dispatch identifiers to their symbol.
    stopwatch.reset()
    switch result {
    case .success(let solution, _):
      try TypeApplier(context: context, solution: solution).visit(module)

    case .failure(let errors):
      for error in errors {
        context.add(
          error: SAError.unsolvableConstraint(constraint: error.constraint, cause: error.cause),
          on: error.constraint.location.resolved)
      }
    }
    let dispatchTime = stopwatch.elapsed

    // Output verbose informations.
    if verbosity >= .verbose {
      System.err.print("Loading module '\(moduleID.qualifiedName)' ...".styled("bold"))
      System.err.print("- Parsed in \(parseTime.humanFormat)")
      System.err.print("- Created type constraints in \(constraintCreationTime.humanFormat)")
      if verbosity >= .debug {
        for constraint in context.typeConstraints {
          constraint.prettyPrint(in: System.err, level: 2)
        }
      }
      System.err.print("- Solved type constraints in \(solvingTime.humanFormat)")
      System.err.print("- Dispatched symbols in \(dispatchTime.humanFormat)")
      System.err.print()
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
