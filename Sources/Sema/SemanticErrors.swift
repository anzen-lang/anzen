import AST

extension Issue {

  // MARK: Semantic errors

  static func ambiguousFunctionUse(name: String, candidates: [FunDecl]) -> String {
    return "ambiguous use of function '\(name)'"
  }

  static func invalidTypeIdentifier(name: String) -> String {
    return "'\(name)' is not a type"
  }

  static func illegalTopLevelCapture(decl: NamedDecl) -> String {
    return "top-level function cannot close over value \(decl.name) defined in an enclosing scope"
  }

  static func illegalMethodCapture(decl: NamedDecl) -> String {
    return "method cannot close over value \(decl.name) defined in an enclosing scope"
  }

  static func nonExistingNestedType(ownerDecl: NamedDecl, owneeName: String) -> String {
    return "type '\(ownerDecl.name)' does not have a nested type '\(owneeName)'"
  }

  static func unboundIdentifier(name: String) -> String {
    return "use of unbound identifier '\(name)'"
  }

  static func superfluousSpecArg(name: String) -> String {
    return "superfluous specialization argument '\(name)'"
  }

}
