import AST
import Utils

/// Visitor that annotates expressions with their type (as inferred by the type solver), identifiers
/// with their corresponding symbol and functions with their capture set.
///
/// This pass reifies the types of each node, according to the solution it is provided with, and
/// links all identifiers to the appropriate symbol, based on their reified type. This also allows
/// to determine the functions' capture set.
///
/// This pass may fail if the dispatcher is unable to unambiguously determine which symbol an
// identifier should be bound to, which may happen in the presence of overloaded generic functions.
public final class Dispatcher: ASTTransformer {

  public init(context: ASTContext) {
    self.context = context
    self.solution = [:]
  }

  public init(context: ASTContext, solution: SubstitutionTable) {
    self.context = context
    self.solution = solution
  }

  /// The AST context.
  public let context: ASTContext
  /// The substitution map obtained after inference.
  public let solution: SubstitutionTable
  /// The nominal types already reified.
  private var visited: [NominalType] = []
  /// The stack of functions, used to determine capture set.
  private var functions: Stack<FunDecl> = []

  public func transform(_ node: ModuleDecl) throws -> Node {
    visitScopeDelimiter(node)
    return try defaultTransform(node)
  }

  public func transform(_ node: Block) throws -> Node {
    visitScopeDelimiter(node)
    return try defaultTransform(node)
  }

  public func transform(_ node: FunDecl) throws -> Node {
    functions.push(node)
    visitScopeDelimiter(node)
    let transformed = try defaultTransform(node)
    functions.pop()
    return transformed
  }

  public func transform(_ node: TypeIdent) throws -> Node {
    node.type = reify(type: node.type)
    return try defaultTransform(node)
  }

  public func transform(_ node: IfExpr) throws -> Node {
    node.type = reify(type: node.type)
    return try defaultTransform(node)
  }

  public func transform(_ node: LambdaExpr) throws -> Node {
    node.type = reify(type: node.type)
    return try defaultTransform(node)
  }

  public func transform(_ node: BinExpr) throws -> Node {
    node.type = reify(type: node.type)

    let lhs = try transform(node.left) as! Expr
    let rhs = try transform(node.right) as! Expr

    // Transform the binary expression into a function application of the form `lhs.op(rhs)`.
    let opIdent = Ident(name: node.op.rawValue, module: node.module, range: node.range)
    opIdent.scope = (lhs.type as! NominalType).memberScope
    opIdent.type = node.operatorType

    let callee = SelectExpr(
      owner: lhs,
      ownee: try transform(opIdent) as! Ident,
      module: node.module,
      range: node.range)
    callee.type = lhs.type?.metatype

    let arg = CallArg(value: rhs, module: node.module, range: node.range)
    arg.type = rhs.type

    let call = CallExpr(callee: callee, arguments: [arg], module: node.module, range: node.range)
    call.type = node.type

    return call
  }

  public func transform(_ node: UnExpr) throws -> Node {
    node.type = reify(type: node.type)
    return try defaultTransform(node)
  }

  public func transform(_ node: CallExpr) throws -> Node {
    node.type = reify(type: node.type)
    return try defaultTransform(node)
  }

  public func transform(_ node: CallArg) throws -> Node {
    node.type = reify(type: node.type)
    return try defaultTransform(node)
  }

  public func transform(_ node: SubscriptExpr) throws -> Node {
    node.type = reify(type: node.type)
    return try defaultTransform(node)
  }

  public func transform(_ node: SelectExpr) throws -> Node {
    node.type = reify(type: node.type)
    node.owner = try node.owner.map { try transform($0) as! Expr }

    let ownerTy = node.owner != nil
      ? node.owner!.type!
      : node.type!

    // Now that the owner's type has been inferred, we can determine the scope of the ownee. Note
    // that we can expect the owner to be either a nominal type or the metatype of a nominal type,
    // as other types may not have members.
    switch ownerTy {
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
      unreachable()
    }

    // Dispatch the symbol of the ownee, now that its scope's been determined.
    node.ownee = try transform(node.ownee) as! Ident

    return node
  }

  public func transform(_ node: Ident) throws -> Node {
    node.type = node.type.map { solution.reify(type: $0, in: context, skipping: &visited) }
    node.specializations = try Dictionary(
      uniqueKeysWithValues: node.specializations.map({ try ($0, transform($1)) }))

    var scope = node.scope
    var choices: [Symbol] = []
    while scope != nil {
      choices.append(contentsOf: (scope!.symbols[node.name] ?? []).filter({ (symbol) -> Bool in
        var bindings: [PlaceholderType: TypeBase] = [:]
        return specializes(lhs: node.type!, rhs: symbol.type!, in: context, bindings: &bindings)
      }))
      scope = scope?.parent
    }

    // FIXME: Disambiguise when there are several choices.
    assert(choices.count > 0)
    node.symbol = choices.first!

    // Check whether the identifier should be registered in a capture set.
    for fn in functions {
      if (node.symbol! != fn.symbol) && node.symbol!.scope.isAncestor(of: fn.innerScope!) {
        // If the identifier doesn't refer to neither a function's parameter, nor a local variable,
        // nor the function itself, then it should figure in the capture set. However, note that
        // global function names will be included as well. Those should be removed in a later pass,
        // if it can be established they refer to thin functions.
        fn.captures.insert(node.symbol!)
      } else {
        // If a function doesn't capture a particular symbol, neither will the outer ones.
        break
      }
    }

    return node
  }

  private func visitScopeDelimiter(_ node: ScopeDelimiter) {
    if let scope = node.innerScope {
      for symbol in scope.symbols.values.joined() {
        symbol.type = symbol.type.map { solution.reify(type: $0, in: context, skipping: &visited) }
      }
    }
  }

  private func reify(type: TypeBase?) -> TypeBase? {
    return type.map { solution.reify(type: $0, in: context, skipping: &visited) }
  }

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

  case (is TypeVariable, _), (_, is TypeVariable):
    preconditionFailure("Unexpected type variable, did you forget to reify?")

  default:
    return false
  }
}
