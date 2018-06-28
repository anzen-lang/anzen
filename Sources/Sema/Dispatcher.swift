import AST

/// Visitor that annotate the AST with inferred types and corresponding symbols.
///
/// This pass reifies the types of each node, according to the solution it is provided, and link all
/// identifiers to the appropriate symbol, based on their reified type. Note that this pass may fail
/// if the dispatcher is unable to unambiguously determine which symbol an identifier should be
/// bound to, which may happen in the presence of overloaded generic functions.
public final class Dispatcher: ASTVisitor, SAPass {

  public init(context: ASTContext) {
    self.context = context
    self.solution = [:]
  }

  public init(context: ASTContext, solution: SubstitutionTable) {
    self.context = context
    self.solution = solution
  }

  public func visit(_ node: ModuleDecl) throws {
    if let scope = node.innerScope {
      for symbol in scope.symbols.values.joined() {
        symbol.type = symbol.type.map { solution.reify(type: $0, in: context, skipping: &visited) }
      }
    }
    try traverse(node)
  }

  public func visit(_ node: Block) throws {
    if let scope = node.innerScope {
      for symbol in scope.symbols.values.joined() {
        symbol.type = symbol.type.map { solution.reify(type: $0, in: context, skipping: &visited) }
      }
    }
    try traverse(node)
  }

  public func visit(_ node: FunDecl) throws {
    if let scope = node.innerScope {
      for symbol in scope.symbols.values.joined() {
        symbol.type = symbol.type.map { solution.reify(type: $0, in: context, skipping: &visited) }
      }
    }
    try traverse(node)
  }

  public func visit(_ node: StructDecl) throws {
    if let scope = node.innerScope {
      for symbol in scope.symbols.values.joined() {
        symbol.type = symbol.type.map { solution.reify(type: $0, in: context, skipping: &visited) }
      }
    }
    try traverse(node)
  }

  public func visit(_ node: InterfaceDecl) throws {
    if let scope = node.innerScope {
      for symbol in scope.symbols.values.joined() {
        symbol.type = symbol.type.map { solution.reify(type: $0, in: context, skipping: &visited) }
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

  public func visit(_ node: CallArg) throws {
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }
    try traverse(node)
  }

  public func visit(_ node: SelectExpr) throws {
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    let ownerType: TypeBase
    if let owner = node.owner {
      try visit(owner)
      ownerType = owner.type!
    } else {
      ownerType = node.type!
    }

    // Now that the owner's type has been inferred, we can determine the scope of the ownee. Note
    // that we can expect the owner to be either a nominal type or the metatype of a nominal type,
    // as other types may not have members.
    switch ownerType {
    case let nominal as NominalType:
      node.ownee.scope = nominal.memberScope

    case let bound as BoundGenericType:
      node.ownee.scope = (bound.unboundType as! NominalType).memberScope

    case let meta as Metatype where meta.type is NominalType:
      node.ownee.scope = (meta.type as! NominalType).memberScope!.parent

    case let meta as Metatype where meta.type is BoundGenericType:
      let unbound = (meta.type as! BoundGenericType).unboundType
      node.ownee.scope = (unbound as! NominalType).memberScope!.parent

    default:
      fatalError("\(ownerType) does not have a member scope")
    }
    try visit(node.ownee)
  }

  public func visit(_ node: Ident) throws {
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }
    try traverse(node)

    var scope = node.scope
    var choices: [Symbol] = []
    while scope != nil {
      choices.append(contentsOf: (scope!.symbols[node.name] ?? []).filter({ (symbol) -> Bool in
        var bindings: [PlaceholderType: TypeBase] = [:]
        return specializes(lhs: node.type!, rhs: symbol.type!, in: context, bindings: &bindings)
      }))
      scope = scope?.parent
    }
    assert(choices.count > 0)

    // FIXME: Desambiguise when there are several choices.
    node.symbol = choices[0]
  }

  /// The AST context.
  public let context: ASTContext
  /// The substitution map obtained after inference.
  public let solution: SubstitutionTable
  /// The nominal types already reified.
  private var visited: [NominalType] = []

}

private func specializes(
  lhs: TypeBase,
  rhs: TypeBase,
  in context: ASTContext,
  bindings: inout [PlaceholderType: TypeBase]) -> Bool
{
  switch (lhs, rhs) {
  case (_, _) where lhs == rhs:
    return true

  case (_, let right as PlaceholderType):
    if let type = bindings[right] {
      return specializes(lhs: lhs, rhs: type, in: context, bindings: &bindings)
    }
    bindings[right] = lhs
    return true

  case (let left as BoundGenericType, _):
    let closed = left.unboundType is NominalType
      ? left.unboundType
      : left.close(using: left.bindings, in: context)
    return specializes(lhs: closed, rhs: rhs, in: context, bindings: &bindings)

  case (_, let right as BoundGenericType):
    return specializes(lhs: right, rhs: lhs, in: context, bindings: &bindings)

  case (let left as Metatype, let right as Metatype):
    return specializes(lhs: left.type, rhs: right.type, in: context, bindings: &bindings)

  case (let left as FunctionType, let right as FunctionType):
    if left.placeholders.isEmpty && right.placeholders.isEmpty {
      return left == right
    }

    guard left.domain.count == right.domain.count
      else { return false }
    for params in zip(left.domain, right.domain) {
      guard params.0.label == params.1.label
        else { return false }
      guard specializes(lhs: params.0.type, rhs: params.1.type, in: context, bindings: &bindings)
        else { return false }
    }
    return specializes(lhs: left.codomain, rhs: right.codomain, in: context, bindings: &bindings)

  default:
    return false
  }
}
