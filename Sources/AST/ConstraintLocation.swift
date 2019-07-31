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
  public let paths: [ConstraintPath]

  public init(anchor: ASTNode, paths: [ConstraintPath]) {
    precondition(!paths.isEmpty)
    self.anchor = anchor
    self.paths = paths
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

  public static func location(_ anchor: ASTNode, _ paths: ConstraintPath...)
    -> ConstraintLocation
  {
    return ConstraintLocation(anchor: anchor, paths: paths)
  }

  public static func + (lhs: ConstraintLocation, rhs: ConstraintPath) -> ConstraintLocation {
    return ConstraintLocation(anchor: lhs.anchor, paths: lhs.paths + [rhs])
  }

}

/// Describes a derivation step to reach the exact location of a constraint from an anchor node.
public enum ConstraintPath: Equatable {

  /// The type annotation of a property or parameter declaration.
  case annotation
  /// The operator of a binary expression.
  case binaryOperator
  // The right operand of a binary expression.
  case binaryRHS
  /// A generic binding.
  case binding(TypePlaceholder)
  /// The call site of a function.
  case call
  /// The codomain of a function type.
  case codomain
  /// The condition of an `if` or a `while` statement.
  case condition
  /// An identifier.
  case identifier
  /// The i-th parameter of a function.
  case parameter(Int)
  /// The r-value of a binding statement.
  case rvalue
  /// The ownee of a select expression.
  case select

}
