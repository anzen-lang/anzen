import Utils
import SystemKit

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

extension Constraint {

  public func prettyPrint(in console: Console = System.err, level: Int = 0) {
    let ident = String(repeating: " ", count: level * 2)
    console.print(
      ident + location.anchor.range.start.description.styled("< 6") + ": ",
      terminator: "")

    switch kind {
    case .equality:
      console.print("\(types!.t) ≡ \(types!.u)".styled("bold"))
    case .conformance:
      console.print("\(types!.t) ≤ \(types!.u)".styled("bold"))
    case .member:
      console.print("\(types!.t).\(member!) ≡ \(types!.u)".styled("bold"))
    case .disjunction:
      console.print("")
      for constraint in choices {
        constraint.prettyPrint(in: console, level: level + 1)
      }
    }
  }

}
