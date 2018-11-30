/// Locates a constraint within an expression.
///
/// So as to better diagnose inference issues, it is important to keep track of the expression or
/// statement in the AST that engendered a particular condition. Additionally, as constraints may
/// be decomposed during the inference process (e.g. `(a: T) -> U ~= (a: A) -> B` decomposes into
/// `T ~= A && U ~= B`), we also need to keep track of the location of the constraint that was
/// decomposed.
///
/// We use the same approach as Swift's compiler to tackle this issue:
/// A constraint location is composed of an anchor, that describes the node within the AST from
/// which the constraint originates, and of one or more paths that describe the derivation steps
/// from the anchor.
public struct ConstraintLocation {

  public init(anchor: Node, paths: [ConstraintPath]) {
    precondition(!paths.isEmpty)
    self.anchor = anchor
    self.paths = paths
  }

  /// The node at which the constraint (or the one from which it derivates) was created.
  public let anchor: Node
  /// The path from the anchor to the exact node the constraint is about.
  public let paths: [ConstraintPath]

  /// The resolved path of the location, i.e. the node it actually points to.
  ///
  /// This property is computed by following the paths components from the anchor. For instance, if
  /// if the path is `call -> parameter(0)`, and the anchor is a `CallExpr` of the form `f(x = 2)`,
  /// then the resolved path is the literal `2`.
  ///
  /// If the path can't be followed until then end, the deepest resolved node is returned.
  public var resolved: Node {
    var leaf = anchor

    for path in paths {
      switch path {
      case .rvalue:
        switch anchor {
        case let binding as BindingStmt:
          leaf = binding.rvalue
        case let binding as PropDecl where binding.initialBinding != nil:
          leaf = binding.initialBinding!.value
        case let binding as ParamDecl where binding.defaultValue != nil:
          leaf = binding.defaultValue!
        case let binding as CallArg:
          leaf = binding.value
        default:
          return leaf
        }

      default:
        continue
      }
    }

    return leaf
  }

  public static func location(_ anchor: Node, _ paths: ConstraintPath...)
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
  case binding(PlaceholderType)
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
