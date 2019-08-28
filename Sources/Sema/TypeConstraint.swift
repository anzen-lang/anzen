import AST
import Utils

/// A type constraint.
public protocol TypeConstraint {

  /// The constraint's priority.
  ///
  /// This property is used as an heuristic to determine which constraints should be solved first,
  /// so as to reduce the size of the solution space.
  static var priority: Int { get }

}

/// An equality constraint `T ~= U` that requires `T` to match `U`.
public struct TypeEqualityConstraint: TypeConstraint, CustomStringConvertible {

  /// The location from which the constraint originates.
  public let location: ConstraintLocation

  public let t: TypeBase
  public let u: TypeBase

  public init(t: TypeBase, u: TypeBase, at location: ConstraintLocation) {
    self.t = t
    self.u = u
    self.location = location
  }

  public static let priority = 500

  // MARK: CustomStringConvertible

  public var description: String {
    return "\(t) ~= \(u)"
  }

}

/// A conformance constraint `T <= U` that requires `T` to be identical to or conforming `U`.
///
/// If the types aren't equal, there are two ways `T` can still conform to `U`.
/// * `T` is a nominal type that implements or extends an interface `U`.
/// * `T` and `U` are function whose domains and codomains conform to each other. For instance if
///   `T = (l0: A0, ..., tn: An) -> B` and `U = (l0: C0, ..., Cn) -> D`, then `T <= U` holds if
///   `Ai <= Ci` and `B <= D`.
public struct TypeConformanceConstraint: TypeConstraint, CustomStringConvertible {

  /// The location from which the constraint originates.
  public let location: ConstraintLocation

  public let t: TypeBase
  public let u: TypeBase

  public init(t: TypeBase, u: TypeBase, at location: ConstraintLocation) {
    self.t = t
    self.u = u
    self.location = location
  }

  public static let priority: Int = 400

  // MARK: CustomStringConvertible

  public var description: String {
    return "\(t) <= \(u)"
  }

}

/// A construction constraint `T <+ U` requires `U` to be the kind of some type and `T` the
/// signature of a construtor thereof.
public struct TypeConstructionConstraint: TypeConstraint, CustomStringConvertible {

  /// The location from which the constraint originates.
  public let location: ConstraintLocation

  public let t: TypeBase
  public let u: TypeBase

  public init(t: TypeBase, u: TypeBase, at location: ConstraintLocation) {
    self.t = t
    self.u = u
    self.location = location
  }

  public static let priority: Int = 300

  // MARK: CustomStringConvertible

  public var description: String {
    return "\(t) <+ \(u)"
  }

}

/// A type specialization constraint `T <s U` requires either that `T` be a specialization of a
/// generic type `U`, or that `T` be equal to `U`.
///
/// This constraint typically serves to typecheck the callee of a function call.
public struct TypeSpecializationConstraint: TypeConstraint, CustomStringConvertible {

  /// The location from which the constraint originates.
  public let location: ConstraintLocation

  public let t: FunType
  public let u: TypeBase

  public init(t: FunType, u: TypeBase, at location: ConstraintLocation) {
    self.t = t
    self.u = u
    self.location = location
  }

  public static let priority: Int = 300

  // MARK: CustomStringConvertible

  public var description: String {
    return "\(t) <s \(u)"
  }

}

/// A value member constraint `T ~= U.name` that requires `U` to have a value member `name` whose
/// type matches `T`
public struct TypeValueMemberConstraint: TypeConstraint, CustomStringConvertible {

  /// The location from which the constraint originates.
  public let location: ConstraintLocation

  public let t: TypeBase
  public let u: TypeBase
  public let memberName: String

  public init(t: TypeBase, u: TypeBase, memberName: String, at location: ConstraintLocation) {
    self.t = t
    self.u = u
    self.memberName = memberName
    self.location = location
  }

  public static let priority: Int = 200

  // MARK: CustomStringConvertible

  public var description: String {
    return "\(t) ~= (\(u)).\(memberName)"
  }

}

/// A type member constraint `T ~= U::name` that requires `U` to have a type member `name` whose
/// type matches `T`
public struct TypeTypeMemberConstraint: TypeConstraint {

  /// The location from which the constraint originates.
  public let location: ConstraintLocation

  public let t: TypeBase
  public let u: TypeBase
  public let memberName: String

  public init(t: TypeBase, u: TypeBase, memberName: String, at location: ConstraintLocation) {
    self.t = t
    self.u = u
    self.memberName = memberName
    self.location = location
  }

  public static let priority: Int = 200

}

/// A disjunction of constraints
public struct TypeConstraintDisjunction: TypeConstraint, CustomStringConvertible {

  public typealias Element = (constraint: TypeConstraint, weight: Int)

  public let choices: [Element]

  public init<S>(choices: S) where S: Sequence, S.Element == Element {
    self.choices = Array(choices)
  }

  public static let priority: Int = 0

  // MARK: CustomStringConvertible

  public var description: String {
    return choices.map({ "(\($0.constraint))" }).joined(separator: " | ")
  }

}

/// A disjunction builder.
public struct TypeConstraintDisjunctionBuilder {

  public var choices: [TypeConstraintDisjunction.Element] = []

  public init() {}

  public mutating func add(_ constraint: TypeConstraint, weight: Int = 0) {
    choices.append((constraint: constraint, weight: weight))
  }

  public func finalize() -> TypeConstraint {
    assert(choices.count > 0)
    return choices.count == 1
      ? choices[0].constraint
      : TypeConstraintDisjunction(choices: choices)
  }

}
