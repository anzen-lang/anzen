import Utils

// MARK: - Stream operator

precedencegroup StreamPrecedence {
  associativity: left
  lowerThan: TernaryPrecedence
}

infix operator <<<: StreamPrecedence

// MARK: - AST Dumper

/// Dumps an AST node as an S-expression into the given text output stream.
public final class ASTDumper<OutputStream>: ASTVisitor where OutputStream: TextOutputStream {

  /// The output stream.
  public var outputStream: OutputStream
  /// The current identation level.
  private var level: Int = 0
  /// A string of whitespaces corresponding to the current identation level.
  private var indent: String {
    return String(repeating: "  ", count: level)
  }

  public init(to outputStream: OutputStream) {
    self.outputStream = outputStream
  }

  public func visit(_ node: MainCodeDecl) {
    self <<< indent <<< "(main_code_decl"
    if !node.stmts.isEmpty {
      self <<< "\n"
      withIndentation { self <<< node.stmts }
    }
    self <<< ")"
  }

  public func visit(_ node: PropDecl) {
    self <<< indent <<< "(prop_decl"
    if node.isReassignable {
      self <<< " reassignable"
    }
    self <<< " name='\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      if !node.attrs.isEmpty {
        self <<< "\n" + indent <<< "(attrs\n"
        withIndentation { self <<< node.attrs.sorted() }
        self <<< ")"
      }
      if !node.modifiers.isEmpty {
        self <<< "\n" + indent <<< "(modifiers\n"
        withIndentation { self <<< node.modifiers.sorted() }
        self <<< ")"
      }
      if let sign = node.sign {
        self <<< "\n" <<< indent <<< "(sign\n"
        withIndentation { sign.accept(visitor: self) }
        self <<< ")"
      }
      if let (op, value) = node.initializer {
        self <<< "\n" <<< indent <<< "(initializer\n"
        withIndentation {
          op.accept(visitor: self)
          self <<< "\n"
          value.accept(visitor: self)
        }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: FunDecl) {
    self <<< indent <<< "(fun_decl \(node.kind)"
    self <<< " name='\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      if !node.attrs.isEmpty {
        self <<< "\n" + indent <<< "(attrs\n"
        withIndentation { self <<< node.attrs.sorted() }
        self <<< ")"
      }
      if !node.modifiers.isEmpty {
        self <<< "\n" + indent <<< "(modifiers\n"
        withIndentation { self <<< node.modifiers.sorted() }
        self <<< ")"
      }
      if !node.genericParams.isEmpty {
        self <<< "\n" <<< indent <<< "(generic_params\n"
        withIndentation { self <<< node.genericParams }
        self <<< ")"
      }
      if !node.params.isEmpty {
        self <<< "\n" <<< indent <<< "(params\n"
        withIndentation { self <<< node.params }
        self <<< ")"
      }
      if let codom = node.codom {
        self <<< "\n" <<< indent <<< "(codom\n"
        withIndentation { self <<< codom }
        self <<< ")"
      }
      if let body = node.body {
        self <<< "\n" <<< indent <<< "(body\n"
        withIndentation { self <<< body }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: ParamDecl) {
    self <<< indent <<< "(param_decl"
    self <<< " name='\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      if let sign = node.sign {
        self <<< "\n" <<< indent <<< "(sign\n"
        withIndentation { sign.accept(visitor: self) }
        self <<< ")"
      }
      if let value = node.defaultValue {
        self <<< "\n" <<< indent <<< "(default_value\n"
        withIndentation { value.accept(visitor: self) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: GenericParamDecl) {
    self <<< indent <<< "(generic_param_decl"
    self <<< " name='\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    self <<< ")"
  }

  public func visit(_ node: InterfaceDecl) {
    self <<< indent <<< "(interface_decl"
    self <<< " name='\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      if !node.genericParams.isEmpty {
        self <<< "\n" <<< indent <<< "(generic_params\n"
        withIndentation { self <<< node.genericParams }
        self <<< ")"
      }
      if let body = node.body {
        self <<< "\n" <<< indent <<< "(body\n"
        withIndentation { body.accept(visitor: self) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: StructDecl) {
    self <<< indent <<< "(struct_decl"
    self <<< " name='\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      if !node.genericParams.isEmpty {
        self <<< "\n" <<< indent <<< "(generic_params\n"
        withIndentation { self <<< node.genericParams }
        self <<< ")"
      }
      if let body = node.body {
        self <<< "\n" <<< indent <<< "(body\n"
        withIndentation { body.accept(visitor: self) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: UnionDecl) {
    self <<< indent <<< "(union_decl"
    self <<< " name='\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      if !node.genericParams.isEmpty {
        self <<< "\n" <<< indent <<< "(generic_params\n"
        withIndentation { self <<< node.genericParams }
        self <<< ")"
      }
      if let body = node.body {
        self <<< "\n" <<< indent <<< "(body\n"
        withIndentation { body.accept(visitor: self) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: UnionNestedDecl) {
    self <<< indent <<< "(union_nested_decl\n"
    withIndentation { node.nestedDecl.accept(visitor: self) }
    self <<< ")"
  }

  public func visit(_ node: TypeExtDecl) {
    self <<< indent <<< "(type_ext_decl"
    withIndentation {
      self <<< "\n" <<< indent <<< "(ext_type_sign\n"
      withIndentation { node.extTypeSign.accept(visitor: self) }
      self <<< ")\n" <<< indent <<< "(body\n"
      withIndentation { node.body.accept(visitor: self) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: BuiltinTypeDecl) {
    self <<< indent <<< "(builtin_type_decl \(node.name))"
  }

  public func visit(_ node: QualTypeSign) {
    self <<< indent <<< "(qual_type_sign"
    if !node.quals.isEmpty {
      self <<< " \(node.quals)"
    }
    self <<< " type='" <<< node.type <<< "'"
    if let sign = node.sign {
      self <<< "\n"
      withIndentation { sign.accept(visitor: self) }
    }
    self <<< ")"
  }

  public func visit(_ node: IdentSign) {
    self <<< indent <<< "(type_ident"
    self <<< " name='\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      for (key, value) in node.specArgs {
        self <<< "\n" <<< indent <<< "(spec_args key='\(key)'\n"
        withIndentation { value.accept(visitor: self) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: NestedIdentSign) {
    self <<< indent <<< "(nested_type_ident"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(owner\n"
      withIndentation { node.owner.accept(visitor: self) }
      self <<< ")\n" <<< indent <<< "(ownee\n"
      withIndentation { node.ownee.accept(visitor: self) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: ImplicitNestedIdentSign) {
    self <<< indent <<< "(nested_type_ident"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(ownee\n"
      withIndentation { node.ownee.accept(visitor: self) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: FunSign) {
    self <<< indent <<< "(fun_sign"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      if !node.params.isEmpty {
        self <<< "\n" <<< indent <<< "(params\n"
        withIndentation { self <<< node.params }
        self <<< ")"
      }
      if let codom = node.codom {
        self <<< "\n" <<< indent <<< "(codom\n"
        withIndentation { codom.accept(visitor: self) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: ParamSign) {
    self <<< indent <<< "(param_sign"
    self <<< " label='" <<< node.label <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(sign\n"
      withIndentation { node.sign.accept(visitor: self) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: InvalidSign) {
    self <<< indent <<< "(invalid_sign "
    self <<< " type='" <<< node.type <<< "'"
    self <<< ")"
  }

  public func visit(_ node: BraceStmt) {
    self <<< indent <<< "(brace_stmt"
    if !node.stmts.isEmpty {
      self <<< "\n"
      withIndentation { self <<< node.stmts }
    }
    self <<< ")"
  }

  public func visit(_ node: IfStmt) {
    self <<< indent <<< "(if_stmt"
    withIndentation {
      self <<< "\n" <<< indent <<< "(condition\n"
      withIndentation { node.condition.accept(visitor: self) }
      self <<< ")\n" <<< indent <<< "(then_stmt\n"
      withIndentation { node.thenStmt.accept(visitor: self) }
      self <<< ")"
      if let elseStmt = node.elseStmt {
        self <<< "\n" <<< indent <<< "(else_stmt\n"
        withIndentation { elseStmt.accept(visitor: self) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: WhileStmt) {
    self <<< indent <<< "(while_stmt"
    withIndentation {
      self <<< "\n" <<< indent <<< "(condition\n"
      withIndentation { node.condition.accept(visitor: self) }
      self <<< ")\n"
      node.body.accept(visitor: self)
    }
    self <<< ")"
  }

  public func visit(_ node: BindingStmt) {
    self <<< indent <<< "(bind_stmt"
    withIndentation {
      self <<< "\n" <<< indent <<< "(op\n"
      withIndentation { node.op.accept(visitor: self) }
      self <<< ")\n" <<< indent <<< "(lvalue\n"
      withIndentation { node.lvalue.accept(visitor: self) }
      self <<< ")\n" <<< indent <<< "(rvalue\n"
      withIndentation { node.rvalue.accept(visitor: self) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: ReturnStmt) {
    self <<< indent <<< "(return_stmt"
    if let (op, value) = node.binding {
      withIndentation {
        self <<< "\n" <<< indent <<< "(binding\n"
        withIndentation { op.accept(visitor: self) }
        self <<< "\n"
        value.accept(visitor: self)
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: InvalidStmt) {
    self <<< indent <<< "(invalid_stmt)"
  }

  public func visit(_ node: NullExpr) {
    self <<< indent <<< "(null_expr"
    self <<< " type='" <<< node.type <<< "'"
    self <<< ")"
  }

  public func visit(_ node: LambdaExpr) {
    self <<< indent <<< "(lambda_expr"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      if !node.params.isEmpty {
        self <<< "\n" <<< indent <<< "(params\n"
        withIndentation { self <<< node.params }
        self <<< ")"
      }
      if let codom = node.codom {
        self <<< "\n" <<< indent <<< "(codom\n"
        withIndentation { codom.accept(visitor: self) }
        self <<< ")"
      }
      self <<< "\n" <<< indent <<< "(body\n"
      withIndentation { node.body.accept(visitor: self) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: UnsafeCastExpr) {
    self <<< indent <<< "(unsafe_cast_expr"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n"
      node.operand.accept(visitor: self)
      self <<< "\n"
      node.castSign.accept(visitor: self)
    }
    self <<< ")"
  }

  public func visit(_ node: InfixExpr) {
    self <<< indent <<< "(infix_expr"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n"
      node.op.accept(visitor: self)
      self <<< "\n"
      node.lhs.accept(visitor: self)
      self <<< "\n"
      node.rhs.accept(visitor: self)
    }
    self <<< ")"
  }

  public func visit(_ node: PrefixExpr) {
    self <<< indent <<< "(prefix_expr"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n"
      node.op.accept(visitor: self)
      self <<< "\n"
      node.operand.accept(visitor: self)
    }
    self <<< ")"
  }

  public func visit(_ node: CallExpr) {
    self <<< indent <<< "(call_expr"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(callee\n"
      withIndentation { node.callee.accept(visitor: self) }
      self <<< ")"
      if !node.args.isEmpty {
        self <<< "\n" <<< indent <<< "(args\n"
        withIndentation { self <<< node.args }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: CallArgExpr) {
    self <<< indent <<< "(call_arg_expr"
    self <<< " '" <<< node.label <<< "'"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(op\n"
      withIndentation { node.op.accept(visitor: self) }
      self <<< ")\n" <<< indent <<< "(value\n"
      withIndentation { node.value.accept(visitor: self) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: IdentExpr) {
    self <<< indent <<< "(ident_expr"
    self <<< " name='\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      for (key, value) in node.specArgs {
        self <<< "\n" <<< indent <<< "(spec_args key='\(key)'\n"
        withIndentation { value.accept(visitor: self) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: SelectExpr) {
    self <<< indent <<< "(select_expr"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(owner\n"
      withIndentation { node.owner.accept(visitor: self) }
      self <<< ")\n" <<< indent <<< "(ownee\n"
      withIndentation { node.ownee.accept(visitor: self) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: ImplicitSelectExpr) {
    self <<< indent <<< "(implicit_select_expr"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(ownee\n"
      withIndentation { node.ownee.accept(visitor: self) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: ArrayLitExpr) {
    self <<< indent <<< "(array_lit_expr"
    self <<< " type='" <<< node.type <<< "'"
    if !node.elems.isEmpty {
      self <<< "\n"
      withIndentation { self <<< node.elems }
    }
    self <<< ")"
  }

  public func visit(_ node: SetLitExpr) {
    self <<< indent <<< "(set_lit_expr"
    self <<< " type='" <<< node.type <<< "'"
    if !node.elems.isEmpty {
      self <<< "\n"
      withIndentation { self <<< node.elems }
    }
    self <<< ")"
  }

  public func visit(_ node: MapLitExpr) {
    self <<< indent <<< "(map_lit_expr"
    self <<< " type='" <<< node.type <<< "'"
    if !node.elems.isEmpty {
      withIndentation {
        self <<< "\n" <<< indent <<< "(elems\n"
        withIndentation { self <<< node.elems }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: MapLitElem) {
    self <<< indent <<< "(map_lit_elem"
    withIndentation {
      self <<< "\n" <<< indent <<< "(key\n"
      withIndentation { node.key.accept(visitor: self) }
      self <<< ")\n" <<< indent <<< "(value\n"
      withIndentation { node.value.accept(visitor: self) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: BoolLitExpr) {
    self <<< indent <<< "(bool_lit_expr value='\(node.value)'"
    self <<< " type='" <<< node.type <<< "'"
    self <<< ")"
  }

  public func visit(_ node: IntLitExpr) {
    self <<< indent <<< "(int_lit_expr value='\(node.value)'"
    self <<< " type='" <<< node.type <<< "'"
    self <<< ")"
  }

  public func visit(_ node: FloatLitExpr) {
    self <<< indent <<< "(float_lit_expr value='\(node.value)'"
    self <<< " type='" <<< node.type <<< "'"
    self <<< ")"
  }

  public func visit(_ node: StrLitExpr) {
    self <<< indent <<< "(str_lit_expr value='\(node.value)'"
    self <<< " type='" <<< node.type <<< "'"
    self <<< ")"
  }

  public func visit(_ node: ParenExpr) {
    self <<< indent <<< "(paren_expr "
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(expr\n"
      withIndentation { node.expr.accept(visitor: self) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: InvalidExpr) {
    self <<< indent <<< "(invalid_expr "
    self <<< " type='" <<< node.type <<< "'"
    self <<< ")"
  }

  public func visit(_ node: DeclAttr) {
    self <<< indent <<< "(decl_attr"
    self <<< " name='\(node.name)'"
    if !node.args.isEmpty {
      self <<< " " + node.args.joined(separator: " ")
    }
    self <<< ")"
  }

  public func visit(_ node: DeclModifier) {
    self <<< indent <<< "(decl_modifier \(node.kind))"
  }

  public func visit(_ node: Directive) {
    self <<< indent <<< "(directive"
    self <<< " name='\(node.name)'"
    if !node.args.isEmpty {
      self <<< " " + node.args.joined(separator: " ")
    }
    self <<< ")"
  }

  // MARK: - Helpers

  fileprivate func withIndentation(body: () -> Void) {
    level += 1
    body()
    level -= 1
  }

  @discardableResult
  fileprivate static func <<< (dumper: ASTDumper, items: [Any]) -> ASTDumper {
    for (i, item) in items.enumerated() {
      dumper <<< item
      if i != items.count - 1 {
        dumper <<< "\n"
      }
    }
    return dumper
  }

  @discardableResult
  fileprivate static func <<< (dumper: ASTDumper, item: Any) -> ASTDumper {
    switch item {
    case let string as String:
      dumper.outputStream.write(string)
    case let node as ASTNode:
      node.accept(visitor: dumper)
    case let optional as AnyOptional:
      dumper.outputStream.write(optional.value.map({ String(describing: $0) }) ?? "_")
    case let array as [Any]:
      dumper <<< array
    default:
      dumper.outputStream.write(String(describing: item))
    }
    return dumper
  }

  @discardableResult
  fileprivate static func <<< <T>(dumper: ASTDumper, item: T?) -> ASTDumper {
    dumper.outputStream.write(item.map({ String(describing: $0) }) ?? "_")
    return dumper
  }

}

// MARK: - Helpers

private protocol AnyOptional {
  var value: Any? { get }
}

extension Optional: AnyOptional {
  var value: Any? { return self }
}

extension DeclAttr: Comparable {

  public static func < (lhs: DeclAttr, rhs: DeclAttr) -> Bool {
    if lhs.name == rhs.name {
      return lhs.args.joined() < rhs.args.joined()
    } else {
      return lhs.name < rhs.name
    }
  }

}

extension DeclAttr: CustomStringConvertible {

  public var description: String {
    return ""
  }

}

extension DeclModifier: Comparable {

  public static func < (lhs: DeclModifier, rhs: DeclModifier) -> Bool {
    return lhs.kind.rawValue < rhs.kind.rawValue
  }

}

extension DeclModifier.Kind: CustomStringConvertible {

  public var description: String {
    switch self {
    case .mutating: return "mutating"
    case .static:   return "static"
    }
  }

}

extension FunDecl.Kind: CustomStringConvertible {

  public var description: String {
    switch self {
    case .constructor:
      return "ctor"
    case .destructor:
      return "dtor"
    case .method:
      return "method"
    case .regular:
      return "regular"
    }
  }

}

extension TypeQualSet: CustomStringConvertible {

  public var description: String {
    return contains(.cst) ? "@cst" : "@mut"
  }

}
