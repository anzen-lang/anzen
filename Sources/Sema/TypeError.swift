import AST

enum TypeError {

  case incompatibleParameterLabels(TypeConstraint)
  case incompatibleQualifiers(TypeConstraint)
  case incompatibleTypes(TypeConstraint)
  case noSuchValueMember(TypeValueMemberConstraint)
  case irreducibleConstraints([TypeConstraint])

}
