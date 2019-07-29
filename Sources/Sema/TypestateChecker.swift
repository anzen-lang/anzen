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

  public func visit(_ node: PropDecl) {
    variables[node.symbol!] = node.initialBinding != nil
      ? .assigned
      : .unassigned
    traverse(node)
  }

  public func visit(_ node: FunDecl) {
    if node.kind != .regular && !node.attributes.contains(.static) {
      let selfSymbol = node.innerScope!.symbols["self"]![0]
      variables[selfSymbol] = .assigned

      var members: [Symbol] = []
      if let type = selfSymbol.type as? NominalType {
        members = type.members
      } else if let type = (selfSymbol.type as? BoundGenericType)?.unboundType as? NominalType {
        members = type.members
      }

      if node.kind == .constructor {
        // In a constructor, all members should be initially reassignable.
        for symbol in members {
          variables[symbol] = .unassigned
        }
      } else {
        // In a method or destructor, all members are considered assigned.
        for symbol in members {
          variables[symbol] = .assigned
        }
      }
    }

    traverse(node)
  }

  public func visit(_ node: ParamDecl) {
    variables[node.symbol!] = .assigned
    traverse(node)
  }

  public func visit(_ node: BindingStmt) {
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
      // If the left operand is a select expression, there are situations to consider. If the owner
      // is `self`, which presupposes that we're visiting the body of a member function. In this
      // case we have to check the member's state, as the assignment might correspond to its first
      // assignment in the type constructor. If the owner is any other expression, then we can just
      // check whether the ownee refers to a reassignable property, because definite assignment
      // analysis will have guaranteed that it has been assigned in the instance's constructor.
      let symbol = select.ownee.symbol!
      if (select.owner as? Ident)?.name == "self" {
        assert(variables[symbol] != nil)

        if case .ref = node.op {
          if (variables[symbol] == .assigned) && !symbol.isReassignable {
            context.add(error: SAError.illegalReassignment(name: symbol.name), on: node)
          }
        }
        variables[symbol] = .assigned
      } else {
        if case .ref = node.op {
          if !symbol.isReassignable {
            context.add(error: SAError.illegalReassignment(name: select.ownee.name), on: node)
          }
        }
      }

    default:
      context.add(error: SAError.invalidLValue, on: node)
    }

    traverse(node)
  }

  public func visit(_ node: IfExpr) {
    if let elseBlock = node.elseBlock {
      // If there are two branches, the analysis' result from both path must be merged
      let before = variables
      visit(node.thenBlock)
      let afterThen = variables
      variables = before
      visit(elseBlock)
      let afterElse = variables

      var merged: [Symbol: AssignmentState] = [:]
      let symbols = Set(afterThen.keys).intersection(afterElse.keys)
      for symbol in symbols where afterThen[symbol] == afterElse[symbol] {
        merged[symbol] = afterThen[symbol]
      }
    }

    traverse(node)
  }

}

private enum AssignmentState {

  /// Designates a property that is definitely assigned.
  case assigned
  /// Designates a property that is definitely unassigned.
  case unassigned

}
