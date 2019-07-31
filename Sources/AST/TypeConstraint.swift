import Utils

/// A type constraint.
public protocol TypeConstraint {

  /// The location from which the constraint originates.
  var location: ConstraintLocation { get }

  /// The constraint's priority.
  ///
  /// This property is used as an heuristic to determine which constraints should be solved first,
  /// so as to reduce the size of the solution space.
  static var priority: Int { get }

}

extension TypeConstraint {

  public static func < (lhs: TypeConstraint, rhs: TypeConstraint) -> Bool {
    return type(of: lhs).priority < type(of: rhs).priority
  }

}

/// An equality constraint `T ~= U` that requires `T` to match `U`.
public struct TypeEqualityConstraint: TypeConstraint {

  public let location: ConstraintLocation

  public let t: TypeBase
  public let u: TypeBase

  public init(t: TypeBase, u: TypeBase, location: ConstraintLocation) {
    self.t = t
    self.u = u
    self.location = location
  }

  public static let priority = 500

}

/// A conformance constraint `T <= U` that requires `T` to be identical to or conforming `U`.
///
/// If the types aren't equal, there are two ways `T` can still conform to `U`.
/// * `T` is a nominal type that implements or extends an interface `U`.
/// * `T` and `U` are function whose domains and codomains conform to each other. For instance if
///   `T = (l0: A0, ..., tn: An) -> B` and `U = (l0: C0, ..., Cn) -> D`, then `T <= U` holds if
///   `Ai <= Ci` and `B <= D`.
public struct TypeConformanceConstraint: TypeConstraint {

  public let location: ConstraintLocation
  public let t: TypeBase
  public let u: TypeBase

  public init(t: TypeBase, u: TypeBase, location: ConstraintLocation) {
    self.t = t
    self.u = u
    self.location = location
  }

  public static let priority: Int = 400

}

/// A construction constraint `T <+ U` requires `U` to be the kind of some type and `T` a thereof.
public struct TypeConstructionConstraint: TypeConstraint {

  public let location: ConstraintLocation
  public let t: TypeBase
  public let u: TypeBase

  public init(t: TypeBase, u: TypeBase, location: ConstraintLocation) {
    self.t = t
    self.u = u
    self.location = location
  }

  public static let priority: Int = 300

}

/// A value member constraint `T[.name] ~= U` that requires `T` to have a value member `name` whose
/// type matches `U`
public struct TypeValueMemberConstraint: TypeConstraint {

  public let location: ConstraintLocation
  public let t: TypeBase
  public let u: TypeBase
  public let memberName: String

  public init(t: TypeBase, u: TypeBase, memberName: String, location: ConstraintLocation) {
    self.t = t
    self.u = u
    self.memberName = memberName
    self.location = location
  }

  public static let priority: Int = 200

}

/// A type member constraint `T[::name] ~= U` that requires `T` and `U` to be the kinds of some
/// types, such that `T` has a member `name` whose type matches `U`.
public struct TypeTypeMemberConstraint: TypeConstraint {

  public let location: ConstraintLocation
  public let t: TypeBase
  public let u: TypeBase
  public let memberName: String

  public init(t: TypeBase, u: TypeBase, memberName: String, location: ConstraintLocation) {
    self.t = t
    self.u = u
    self.memberName = memberName
    self.location = location
  }

  public static let priority: Int = 200

}

/// A disjunction of constraints
public struct TypeConstraintDisjunction: TypeConstraint {

  public let location: ConstraintLocation
  public let choices: [TypeConstraint]

  public init<S>(choices: S, location: ConstraintLocation)
    where S: Sequence, S.Element == TypeConstraint
  {
    self.choices = Array(choices)
    self.location = location
  }

  public static let priority: Int = 0

}
