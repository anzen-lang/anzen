import AST
import Utils

public final class CaptureAnalyzer: ASTVisitor {

  public init() {
  }

  /// The stack of functions, used to determine capture set.
  private var functions: Stack<FunDecl> = []

  public func visit(_ node: FunDecl) {
    functions.push(node)
    try! traverse(node)
    functions.pop()

    assert(node.captures.duplicates(groupedBy: { $0.name }).isEmpty)
  }

  public func visit(_ node: SelectExpr) {
    if let owner = node.owner {
      try! visit(owner)
    }
    // Note that we don't visit ownees of select expressions. Although they are identifiers, they
    // can't actually be captured, as only their owner can.
  }

  public func visit(_ node: Ident) {
    for fn in functions {
      if (node.symbol! != fn.symbol) && node.symbol!.scope.isAncestor(of: fn.innerScope!) {
        // If the identifier doesn't refer to neither a function's parameter, nor a local variable,
        // nor the function itself, then it should figure in the capture set. However, note that
        // global function names will be included as well. Those should be removed in a later pass,
        // if it can be established they refer to thin functions.
        if !fn.captures.contains(node.symbol!) {
          fn.captures.append(node.symbol!)
        }
      } else {
        // If a function doesn't capture a particular symbol, neither will the outer ones.
        break
      }
    }
  }

}
