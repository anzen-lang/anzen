import AST

/// Enumeration of the possible static analysis errors.
public enum SAError: Error {

  /// Occurs when a property or type is declared twice in the same scope.
  case duplicateDeclaration(name: String)
  /// Occurs when a symbol is improperly redeclared (e.g. a function overloading a property).
  case invalidRedeclaration(name: String)
  /// Occurs when an non-type identifier is used as a type annotation.
  case invalidTypeIdentifier(name: String)
  /// Occurs when a symbol appears to be not declared in any accessible scope.
  case undefinedSymbol(name: String)
  /// Occurs when a declaration is found outside of any scope.
  case unscopedDeclaration

}
