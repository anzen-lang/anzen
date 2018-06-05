public enum ConstraintKind: Int {

  /// An equality constraint `T ~= U` that requires `T` to match `U`.
  case equality = 3

  /// A conformance constraint `T <= U` that requires `T` to be identical to or conforming `U`.
  ///
  /// If the types aren't, there are two ways `T` can still conform to `U`.
  /// * `T` is a nominal type that implements or extends an interface `U`.
  /// * `T` and `U` are function whose domains and codomains conform to each other. For instance if
  ///   `T = (l0: A0, ..., tn: An) -> B` and `U = (l0: C0, ..., Cn) -> D`, then `T <= U` holds if
  ///   `Ai <= Ci` and `B <= D`.
  case conformance = 2

  /// A construction constraint `T <+ (U0, ..., Un)` that requires `T` to have a constructor that
  /// accepts `(U0, ..., Un)` as parameters.
  // case construction(t: TypeBase, u: [TypeBase])

  /// A member constraint `T[.name] ~= U` that requires `T` to have a member `name` whose type
  /// matches `U`.
  case member = 1

  /// A disjunction of constraints
  case disjunction = 0

}

/// Describes a derivation step to reach the exact location of a constraint from an anchor node.
public enum ConstraintPath {

  /// The type annotation of a property or parameter declaration.
  case annotation
  /// The call site of a function.
  case call
  /// The codomain of a function type.
  case codomain
  /// An identifier.
  case identifier
  /// The opening of a generic type.
  case open
  /// The i-th parameter of a function.
  case parameter(Int)
  /// The r-value of a binding statement.
  case rvalue

}

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

public struct Constraint {

  public init(
    kind: ConstraintKind,
    types: (t: TypeBase, u: TypeBase)? = nil,
    member: String? = nil,
    choices: [Constraint] = [],
    location: ConstraintLocation)
  {
    self.kind = kind
    self.types = types
    self.member = member
    self.choices = choices
    self.location = location
  }

  /// Creates an equality constraint.
  public static func equality(t: TypeBase, u: TypeBase, at location: ConstraintLocation)
    -> Constraint
  {
    return Constraint(kind: .equality, types: (t, u), location: location)
  }

  /// Creates a conformance constraint.
  public static func conformance(t: TypeBase, u: TypeBase, at location: ConstraintLocation)
    -> Constraint
  {
    return Constraint(kind: .conformance, types: (t, u), location: location)
  }

  /// Creates a member constraint.
  public static func member(
    t: TypeBase,
    member: String,
    u: TypeBase,
    at location: ConstraintLocation) -> Constraint
  {
    return Constraint(kind: .member, types: (t, u), member: member, location: location)
  }

  /// Creates a disjunction constraint.
  public static func disjunction(_ choices: [Constraint], at location: ConstraintLocation)
    -> Constraint
  {
    return Constraint(kind: .disjunction, choices: choices, location: location)
  }

  /// The kind of the constraint.
  public let kind: ConstraintKind
  /// The location of the constraint.
  public let location: ConstraintLocation
  /// The types `T` and `U` of a match-relation constraint.
  public let types: (t: TypeBase, u: TypeBase)?
  /// The name in `T[.name]` of a member constraint.
  public let member: String?
  /// The choices of a disjunction constraint.
  public let choices: [Constraint]

  public static func < (lhs: Constraint, rhs: Constraint) -> Bool {
    return lhs.kind.rawValue < rhs.kind.rawValue
  }

}
