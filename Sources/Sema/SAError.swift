import AST

/// Enumeration of the possible static analysis errors.
public enum SAError: Error, CustomStringConvertible {

  /// Occurs when a property or type is declared twice in the same scope.
  case duplicateDeclaration(name: String)
  /// Occurs when a non-reassignable reference is reassigned.
  case illegalReassignment(name: String)
  /// Occurs when a symbol is improperly redeclared (e.g. a function overloading a property).
  case illegalRedeclaration(name: String)
  /// Occurs when an invalid l-value appears as the left operand of an assignment.
  case invalidLValue
  /// Occurs when an non-type identifier is used as a type annotation.
  case invalidTypeIdentifier(name: String)
  /// Occurs when a non-generic type is being explicitly specialized.
  case nonGenericType(type: TypeBase)
  /// Occurs when a superfluous placeholder specialization is provided.
  case superfluousSpecialization(name: String)
  /// Occurs when a symbol appears to be not declared in any accessible scope.
  case undefinedSymbol(name: String)
  /// Occurs when the given type constraint seems unsolvable.
  case unsolvableConstraint(constraint: Constraint, cause: SolverFailureKind)

  public var description: String {
    switch self {
    case .duplicateDeclaration(let name):
      return "duplicate declaration '\(name)'"
    case .illegalReassignment(let name):
      return "illegal reassignment of non-reassignable l-value '\(name)'"
    case .illegalRedeclaration(let name):
      return "illegal redeclaration of '\(name)'"
    case .invalidLValue:
      return "invalid l-value"
    case .invalidTypeIdentifier(let name):
      return "invalid type identifier '\(name)'"
    case .nonGenericType(let type):
      return "non-generic type '\(type)'"
    case .superfluousSpecialization(let name):
      return "superfluous specialization '\(name)'"
    case .undefinedSymbol(let name):
      return "undefined symbol '\(name)'"
    case .unsolvableConstraint:
      return "type error"
    }
  }

}
