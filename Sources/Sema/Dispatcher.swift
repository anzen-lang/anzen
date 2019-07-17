import AST
import Utils

/// Visitor that annotates expressions with their reified type (as inferred by the type solver),
/// and associates identifiers with their corresponding symbol.
///
/// The main purpose of this pass is to resolve identifiers' symbols, so as to know which variable,
/// function or type they refer to. The choice is based on the identifier's inferred type, which is
/// why this pass also reifies all types.
///
/// Dispatching may fail if the pass is unable to unambiguously resolve an identifier's symbol,
/// which may happen in the presence of function declarations whose normalized (and specialized)
/// signature are found identical.
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

  public func transform(_ node: ModuleDecl) throws -> Node {
    visitScopeDelimiter(node)
    return try defaultTransform(node)
  }

  public func transform(_ node: Block) throws -> Node {
    visitScopeDelimiter(node)
    return try defaultTransform(node)
  }

  public func transform(_ node: FunDecl) throws -> Node {
    visitScopeDelimiter(node)
    return try defaultTransform(node)
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

    if (node.op == .peq) || (node.op == .peq) {
      // Transform pointer identity checks into a function application of the form `op(lhs, rhs)`.
      let opIdent = Ident(name: node.op.rawValue, module: node.module, range: node.range)
      opIdent.scope = context.builtinModule.innerScope
      opIdent.symbol = context.builtinModule.functionDeclarations[opIdent.name]?.symbol
      opIdent.type = opIdent.symbol?.type

      let leftArg = CallArg(value: lhs, module: node.module, range: lhs.range)
      leftArg.type = lhs.type
      let rightArg = CallArg(value: rhs, module: node.module, range: rhs.range)
      rightArg.type = rhs.type

      let call = CallExpr(
        callee: opIdent,
        arguments: [leftArg, rightArg],
        module: node.module,
        range: node.range)
      call.type = node.type

      return call
    } else {
      // Transform the binary expression into a function application of the form `lhs.op(rhs)`.
      let opIdent = Ident(name: node.op.rawValue, module: node.module, range: node.range)
      opIdent.scope = (lhs.type as! NominalType).memberScope
      opIdent.type = reify(type: node.operatorType)

      let callee = SelectExpr(
        owner: lhs,
        ownee: try transform(opIdent) as! Ident,
        module: node.module,
        range: node.range)
      callee.type = opIdent.type

      let arg = CallArg(value: rhs, module: node.module, range: node.range)
      arg.type = rhs.type

      let call = CallExpr(callee: callee, arguments: [arg], module: node.module, range: node.range)
      call.type = node.type

      return call
    }
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

    // Once the owner's type's been inferred, we can determine the scope of the ownee. We can
    // expect the owner to be either a nominal type or the metatype of a nominal type, as other
    // types don't have members.
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
      uniqueKeysWithValues: node.specializations.map({
        try ($0, transform($1) as! QualTypeSign)
      }))

    assert(node.scope != nil)
    assert(node.scope!.symbols[node.name] != nil)
    var choices = node.scope!.symbols[node.name]!
    assert(!choices.isEmpty)

    if node.type is FunctionType {

      // Note: there are various situations to consider if the identifier has a function type.
      // * The identifier might refer to a functional property, in which case the only solution
      //   is to dispatch to that property's symbol.
      // * The identifier might refer to a function constructor, in which case we may dispatch to
      //   any constructor symbol in the member scope of the type it refers to.
      // * The identifier might refer directly to a function declaration, in which case we may
      //   dispatch to any overloaded symbol in the accessible scope.

      if !(choices[0].isOverloadable || choices[0].type is Metatype) {
        // First case: the identifier refers to a property.
        assert(choices.count == 1)
        node.symbol = choices[0]
      } else if let ty = (choices[0].type as? Metatype)?.type as? NominalType {
        // Second case: the identifier refers to a constructor.
        choices = ty.memberScope!.symbols["new"]!
        node.symbol = inferSymbol(type: node.type!, choices: choices)
      } else {
        // Thid case: the identifier refers to a function.
        var scope = node.scope
        while let parent = scope?.parent {
          if let symbols = parent.symbols[node.name] {
            guard symbols.first!.isOverloadable
              else { break }
            choices += symbols
          }
          scope = parent
        }
        node.symbol = inferSymbol(type: node.type!, choices: choices)
      }

    } else {
      assert(choices.count == 1)
      node.symbol = choices[0]
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

  private func inferSymbol(type: TypeBase, choices: [Symbol]) -> Symbol {
    // Filter out incompatible symbols.
    let compatible = choices.filter { symbol in
      let ty = symbol.isMethod && !symbol.isStatic
        ? (symbol.type as! FunctionType).codomain
        : symbol.type!
      var bindings: [PlaceholderType: TypeBase] = [:]
      return specializes(lhs: type, rhs: ty, in: context, bindings: &bindings)
    }

    // FIXME: Disambiguise when there are several choices.
    assert(compatible.count > 0)
    return compatible[0]
  }

}
