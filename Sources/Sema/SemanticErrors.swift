import AST

extension Issue {

  // MARK: Semantic errors

  static func invalidTypeIdentifier(name: String) -> String {
    return "'\(name)' is not a type"
  }

  static func nonExistingNestedType(owner: TypeSign, ownee: String) -> String {
    return "type '\(owner)' does not have a nested type '\(ownee)'"
  }

  static func unboundIdentifier(name: String) -> String {
    return "use of unbound identifier '\(name)'"
  }

}
