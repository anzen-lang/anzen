import AST

/// A type constraint factory.
final class TypeConstraintFactory {

  /// The next constraint ID.
  private var nextID: Int = 0

  /// Creates a type equality constraint `T ~= U`.
  func equality(t: TypeBase, u: TypeBase, at location: ConstraintLocation)
    -> TypeEqualityConstraint
  {
    nextID += 1
    return TypeEqualityConstraint(t: t, u: u, at: location, id: nextID)
  }

  /// Creates a type conformance constraint `T <= U`.
  func conformance(t: TypeBase, u: TypeBase, at location: ConstraintLocation)
    -> TypeConformanceConstraint
  {
    nextID += 1
    return TypeConformanceConstraint(t: t, u: u, at: location, id: nextID)
  }

  /// Creates a specialization constraint `T <s U`.
  func specialization(t: FunType, u: TypeBase, at location: ConstraintLocation)
    -> TypeSpecializationConstraint
  {
    nextID += 1
    return TypeSpecializationConstraint(t: t, u: u, at: location, id: nextID)
  }

  /// Creates a value member constraint `T ~= U.name`.
  func valueMember(t: TypeBase, u: TypeBase, memberName: String, at location: ConstraintLocation)
    -> TypeValueMemberConstraint
  {
    nextID += 1
    return TypeValueMemberConstraint(t: t, u: u, memberName: memberName, at: location, id: nextID)
  }

  /// Creates a type member constraint `T ~= U::name`.
  func typeMember(t: TypeBase, u: TypeBase, memberName: String, at location: ConstraintLocation)
    -> TypeTypeMemberConstraint
  {
    nextID += 1
    return TypeTypeMemberConstraint(t: t, u: u, memberName: memberName, at: location, id: nextID)
  }

  /// Creates a disjunction of type constraints.
  func disjunction<S>(choices: S) -> TypeConstraintDisjunction
    where S: Sequence, S.Element == TypeConstraintDisjunction.Element
  {
    nextID += 1
    return TypeConstraintDisjunction(choices: choices, id: nextID)
  }

}
