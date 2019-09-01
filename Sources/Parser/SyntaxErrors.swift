import AST

extension Issue {

  // MARK: Syntax errors

  static func ambiguousCastOrTypeTestOperand() -> String {
    return "infix expressions should be parenthesized when used as operands in cast and type tests"
  }

  static func duplicateGenericParam(key: String) -> String {
    return "duplicate generic parameter name '\(key)'"
  }

  static func expectedSeparator() -> String {
    return "consecutive elements should be separated by ','"
  }

  static func expectedStmtDelimiter() -> String {
    return "consecutive statements should be separated by ';'"
  }

  static func invalidTypeQual(value: String) -> String {
    return "invalid qualifier '\(value)'"
  }

  static func invalidRedeclaration(name: String) -> String {
    return "invalid redeclaration of '\(name)'"
  }

  static func invalidTopLevelStmt(node: ASTNode) -> String {
    switch node {
    case is Stmt, is Expr:
      return "top-level statements are only allowed in main files"
    default:
      return "invalid top-level node '\(node)'"
    }
  }

  static func keywordAsIdent(keyword: String) -> String {
    return "keyword '\(keyword)' cannot be used as an identifier"
  }

  static func missingParamSign() -> String {
    return "parameter declaration requires an explicit type"
  }

  static func nestedExtDecl(extDecl: TypeExtDecl) -> String {
    return "extensions are only allowed at top-level scope"
  }

  static func nonAssociativeOp(op: String) -> String {
    return "use of adjacent non-associative operators '\(op)'"
  }

  static func unexpectedEntity(expected: String?, got found: ASTNode) -> String {
    return expected != nil
      ? "unexpected token '\(found)', expected \(expected!)"
      : "unexpected token '\(found)'"
  }

  static func unexpectedFunAttr(attr: DeclAttrDecl) -> String {
    return "unexpected attribute '\(attr.name)' on function declaration will be ignored"
  }

  static func unexpectedDeclModifier(modifier: DeclModifierDecl) -> String {
    return "modifier '\(modifier.kind)' may only appear in type declaration"
  }

  static func unexpectedPropAttr(attr: DeclAttrDecl) -> String {
    return "unexpected attribute '\(attr.name)' on property declaration will be ignored"
  }

  static func unexpectedToken(expected: String?, got found: Token) -> String {
    return expected != nil
      ? "unexpected token '\(found)', expected \(expected!)"
      : "unexpected token '\(found)'"
  }

}
