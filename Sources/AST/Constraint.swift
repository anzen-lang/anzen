import Utils

public enum ConstraintKind: Int {

  /// An equality constraint `T ~= U` that requires `T` to match `U`.
  case equality = 10

  /// A conformance constraint `T <= U` that requires `T` to be identical to or conforming `U`.
  ///
  /// If the types aren't, there are two ways `T` can still conform to `U`.
  /// * `T` is a nominal type that implements or extends an interface `U`.
  /// * `T` and `U` are function whose domains and codomains conform to each other. For instance if
  ///   `T = (l0: A0, ..., tn: An) -> B` and `U = (l0: C0, ..., Cn) -> D`, then `T <= U` holds if
  ///   `Ai <= Ci` and `B <= D`.
  case conformance = 8

  /// A construction constraint `T <+ U` requires `U` to be the metatype of a nominal type, and `T`
  /// to be a constructor of said type.
  case construction = 6

  /// A member constraint `T[.name] ~= U` that requires `T` to have a member `name` whose type
  /// matches `U`.
  case member = 4

  /// A disjunction of constraints
  case disjunction = 0

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

  /// Creates a construction constraint.
  public static func construction(t: TypeBase, u: TypeBase, at location: ConstraintLocation)
    -> Constraint
  {
    return Constraint(kind: .construction, types: (t, u), location: location)
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

extension Constraint: CustomStringConvertible {

  public var description: String {
    var buffer = ""
    dump(to: &buffer)
    return buffer
  }

  public func dump<OutputStream>(to outputStream: inout OutputStream, level: Int = 0)
    where OutputStream: TextOutputStream
  {
    let ident = String(repeating: " ", count: level * 2)
    outputStream.write(ident + location.anchor.range.start.description.styled("< 6") + ": ")
    switch kind {
    case .equality:
      outputStream.write("\(types!.t) ≡ \(types!.u)\n")
    case .conformance:
      outputStream.write("\(types!.t) ≤ \(types!.u)\n")
    case .member:
      outputStream.write("\(types!.t).\(member!) ≡ \(types!.u)\n")
    case .construction:
      outputStream.write("\(types!.t) <+ \(types!.u)\n")
    case .disjunction:
      outputStream.write("\n")
      for constraint in choices {
        constraint.dump(to: &outputStream, level: level + 1)
      }
    }
  }

}
