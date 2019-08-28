import AST

/// A module pass that infers type variables and checks for type correctness.
public struct TypeCheckerPass {

  /// The compiler context.
  public let context: CompilerContext

  /// The module being processed.
  public let module: Module

  public init(module: Module, context: CompilerContext) {
    assert(module.state == .parsed, "module has not been parsed yet")
    self.context = context
    self.module = module
  }

  public func process() {
    // Extract all type constraints.
    let extractor = TypeConstraintExtractor(context: context)
    for decl in module.decls {
      decl.accept(visitor: extractor)
    }

    for cons in extractor.constraints {
      print(cons)
    }
    print()

    // Solve all type constraints.
    var solver = TypeConstraintSolver(
      constraints: extractor.constraints,
      context: context,
      assumptions: SubstitutionTable())
    let solution = solver.solve()
    solution.substitutions.dump()
    print("weight: \(solution.weight)")
  }

}
