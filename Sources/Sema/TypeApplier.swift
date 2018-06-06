import AST

/// Visitor that annotate the AST with inferred types.
public final class TypeApplier: ASTVisitor, SAPass {

  public init(context: ASTContext) {
    self.context = context
    self.solution = [:]
  }

  public init(context: ASTContext, solution: SubstitutionTable) {
    self.context = context
    self.solution = solution
  }

  public func visit(_ node: PropDecl) throws {
    if let symbol = node.symbol {
      symbol.type = symbol.type.map {
        solution.reify(type: $0, in: context, skipping: &visited)
      }
    }
    try traverse(node)
  }

  public func visit(_ node: FunDecl) throws {
    if let symbol = node.symbol {
      symbol.type = symbol.type.map {
        solution.reify(type: $0, in: context, skipping: &visited)
      }
    }
    try traverse(node)
  }

  public func visit(_ node: ParamDecl) throws {
    if let symbol = node.symbol {
      symbol.type = symbol.type.map {
        solution.reify(type: $0, in: context, skipping: &visited)
      }
    }
    try traverse(node)
  }

  public func visit(_ node: StructDecl) throws {
    if let symbol = node.symbol {
      symbol.type = symbol.type.map {
        solution.reify(type: $0, in: context, skipping: &visited)
      }
    }
    try traverse(node)
  }

  public func visit(_ node: CallExpr) throws {
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }
    try traverse(node)
  }

  public func visit(_ node: Ident) throws {
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }
    try traverse(node)
  }

  /// The AST context.
  public let context: ASTContext
  /// The substitution map obtained after inference.
  public let solution: SubstitutionTable
  /// The nominal types already reified.
  private var visited: [NominalType] = []

}
