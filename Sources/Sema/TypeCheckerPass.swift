import AST

/// A module pass that infers type variables and checks for type correctness.
///
/// This pass must take place after type realization, as it requires all nodes to be associated
/// with a type (fully realized or not).
public struct TypeCheckerPass {

  /// The compiler context.
  public let context: CompilerContext

  /// The module being processed.
  public let module: Module

  /// The checker's type constraint factory.
  private let factory = TypeConstraintFactory()

  public init(module: Module, context: CompilerContext) {
    assert(module.state == .parsed, "module has not been parsed yet")
    self.context = context
    self.module = module
  }

  public func process() {
    // Extract all type constraints.
    let extractor = TypeConstraintExtractor(context: context, factory: factory)
    for decl in module.decls {
      decl.accept(visitor: extractor)
    }

    // Solve all type constraints.
    var solver = TypeConstraintSolver(
      constraints: extractor.constraints,
      context: context,
      factory: factory,
      assumptions: SubstitutionTable())
    let solution = solver.solve()

    // Register the type errors.
    let typeFinalizer = TypeFinalizer(
      context: context,
      substitutions: solution.substitutions.canonized)
    for error in solution.errors {
      error.register(withTypeFinalizer: typeFinalizer)
    }

    // Dispatch the solution.
    let dispatcher = Dispatcher(typeFinalizer: typeFinalizer)
    for decl in module.decls {
      decl.accept(visitor: dispatcher)
    }
  }

}
