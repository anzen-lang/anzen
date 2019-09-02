import AST

/// Locates a constraint within an expression.
///
/// So as to better diagnose inference issues, it is important to keep track of the expression or
/// statement in the AST that engendered a particular condition. Additionally, as constraints may
/// be decomposed during the inference process (e.g. `(a: T) -> U ~= (a: A) -> B` decomposes into
/// `T ~= A && U ~= B`), we also need to keep track of the location of the constraints that were
/// decomposed.
///
/// We use the same approach as Swift's compiler to tackle this issue: constraints are said to be
/// *anchored* at some node, from which a sequence of path elements that represent each point where
/// the anchored was split. In more formal terms, a constraint location denotes the path in the
/// type deduction derivation tree.
public struct ConstraintLocation {

  /// The node at which the constraint is anchored.
  public let anchor: ASTNode
  /// The path from the anchor to the exact entity the constraint is about.
  public let path: [ConstraintPathComponent]

  public init(anchor: ASTNode, path: [ConstraintPathComponent]) {
    precondition(!path.isEmpty)
    self.anchor = anchor
    self.path = path
  }

  /// The resolved path of the location, i.e. the node it actually points to.
  ///
  /// This property is computed by following the paths components from the anchor. For instance, if
  /// if the path is `call -> parameter(0)`, and the anchor is a `CallExpr` of the form `f(x = 2)`,
  /// then the resolved path is the literal `2`.
  ///
  /// If the path can't be followed until then end, the deepest resolved node is returned.
  public var resolved: ASTNode {
    // TODO: Implement me!
    return anchor
  }

  public static func location(_ anchor: ASTNode, _ path: ConstraintPathComponent...)
    -> ConstraintLocation
  {
    return ConstraintLocation(anchor: anchor, path: path)
  }

  public static func + (lhs: ConstraintLocation, rhs: ConstraintPathComponent) -> ConstraintLocation {
    return ConstraintLocation(anchor: lhs.anchor, path: lhs.path + [rhs])
  }

}

/// Describes a derivation step to reach the exact location of a constraint from an anchor node.
public enum ConstraintPathComponent: Equatable {

  /// The operator of an infix expression.
  case infixOp
  // The right operand of an infix expression.
  case infixRHS
  /// A binding statement.
  case binding
  /// The call site of a function.
  case call
  /// The codomain of a function type.
  case codomain
  /// The condition of an `if` or a `while` statement.
  case condition
  /// An identifier.
  case identifier
  /// The initializer of a property or parameter declaration.
  case initializer
  /// The operator of a prefix expression.
  case prefixOp
  /// The i-th parameter of a function.
  case parameter(Int)
  /// The return value of a function.
  case `return`
  /// The ownee of a select expression.
  case select

}
