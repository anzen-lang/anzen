import AST

extension Issue {

  // MARK: Semantic errors

  static func invalidTypeIdentifier(name: String) -> String {
    return "'\(name)' is not a type"
  }

  static func nonExistingNestedType(ownerDecl: NamedDecl, owneeName: String) -> String {
    return "type '\(ownerDecl.name)' does not have a nested type '\(owneeName)'"
  }

  static func unboundIdentifier(name: String) -> String {
    return "use of unbound identifier '\(name)'"
  }

}
