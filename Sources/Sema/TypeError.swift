import AST

enum TypeError {

  case incompatibleParameterLabels(TypeConstraint)
  case incompatibleQualifiers(TypeConstraint)
  case incompatibleTypes(TypeConstraint)
  case noSuchConstructor(TypeConstructionConstraint)
  case noSuchValueMember(TypeValueMemberConstraint)

}
