import AST

/// A visitor that type-check the typestate of each symbol and reference.
public final class TypestateChecker: ASTVisitor {

  /// The AST context.
  public let context: ASTContext
  /// The descriptor associated with each visited variable and parameter.
  private var variables: [Symbol: AssignmentState] = [:]

  public init(context: ASTContext) {
    self.context = context
  }

  public func visit(_ node: PropDecl) throws {
    variables[node.symbol!] = node.initialBinding != nil
      ? .assigned
      : .unassigned
    try traverse(node)
  }

  public func visit(_ node: FunDecl) throws {
    if node.kind != .regular {
      let selfSymbol = node.innerScope!.symbols["self"]![0]
      variables[selfSymbol] = .assigned
    }

    try traverse(node)
  }

  public func visit(_ node: ParamDecl) throws {
    variables[node.symbol!] = .assigned
    try traverse(node)
  }

  public func visit(_ node: BindingStmt) throws {
    switch node.lvalue {
    case let identifier as Ident:
      // If the left operand is an identifier, is should either refer toa visible variable or
      // parameter. In either case, an assignment state should already have beed defined.
      let symbol = identifier.symbol!
      assert(variables[symbol] != nil)

      if case .ref = node.op {
        if (variables[symbol] == .assigned) && !symbol.isReassignable {
          context.add(error: SAError.illegalReassignment(name: identifier.name), on: node)
        }
      }
      variables[symbol] = .assigned

    case let select as SelectExpr:
      // If the left operand is a select expression, then we just have to check that it refers to
      // a reassignable property, since definite assignment guarantees that it must have already
      // been assigned in the instance's constructor.
      let symbol = select.ownee.symbol!

      if case .ref = node.op {
        // FIXME: This approach prevents fields from being assigned by alias in constructors.
        if !symbol.isReassignable {
          context.add(error: SAError.illegalReassignment(name: select.ownee.name), on: node)
        }
      }

    default:
      context.add(error: SAError.invalidLValue, on: node)
    }

    try traverse(node)
  }

  public func visit(_ node: IfExpr) throws {
    if let elseBlock = node.elseBlock {
      // If there are two branches, the analysis' result from both path must be merged
      let before = variables
      try visit(node.thenBlock)
      let afterThen = variables
      variables = before
      try visit(elseBlock)
      let afterElse = variables

      var merged: [Symbol: AssignmentState] = [:]
      let symbols = Set(afterThen.keys).intersection(afterElse.keys)
      for symbol in symbols where afterThen[symbol] == afterElse[symbol] {
        merged[symbol] = afterThen[symbol]
      }
    }

    try traverse(node)
  }

}

private enum AssignmentState {

  /// Designates a property that is definitely assigned.
  case assigned
  /// Designates a property that is definitely unassigned.
  case unassigned

}
