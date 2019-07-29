import Utils

precedencegroup StreamPrecedence {
  associativity: left
  lowerThan: TernaryPrecedence
}

infix operator <<<: StreamPrecedence

public final class ASTDumper<OutputStream>: ASTVisitor where OutputStream: TextOutputStream {

  public init(to outputStream: OutputStream) {
    self.outputStream = outputStream
  }

  public var outputStream: OutputStream

  private var level: Int = 0
  private var indent: String {
    return String(repeating: "  ", count: level)
  }

  public func visit(_ node: ModuleDecl) {
    self <<< indent <<< "(module_decl"
    self <<< " id='" <<< node.id?.qualifiedName <<< "'"
    self <<< " inner_scope='" <<< node.innerScope <<< "'"

    if !node.statements.isEmpty {
      self <<< "\n"
      withIndentation { visit(node.statements) }
    }
    self <<< ")\n"
  }

  public func visit(_ node: Block) {
    self <<< indent <<< "(block"
    self <<< " inner_scope='" <<< node.innerScope <<< "'"

    if !node.statements.isEmpty {
      withIndentation {
        self <<< "\n"
        withIndentation { visit(node.statements) }
      }
    }
    self <<< ")"
  }

  public func visit(_ node: PropDecl) {
    self <<< indent <<< "(prop_decl"
    if !node.attributes.isEmpty {
      self <<< " " + node.attributes.map({ $0.rawValue }).sorted().joined(separator: " ")
    }
    self <<< " '\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    self <<< " symbol='" <<< node.symbol?.name <<< "'"
    self <<< " scope='" <<< node.scope <<< "'"
    withIndentation {
      if let typeAnnotation = node.typeAnnotation {
        self <<< "\n" <<< indent <<< "(type_annotation\n"
        withIndentation { visit(typeAnnotation) }
        self <<< ")"
      }
      if let (op, value) = node.initialBinding {
        self <<< "\n" <<< indent <<< "(initial_binding\n"
        withIndentation {
          self <<< indent <<< "(binding_operator \(op))\n"
          visit(value)
        }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: FunDecl) {
    self <<< indent
    switch node.kind {
    case .regular    : self <<< "(function_decl"
    case .method     : self <<< "(method_decl"
    case .constructor: self <<< "(constructor_decl"
    case .destructor : self <<< "(destructor_decl"
    }
    if !node.attributes.isEmpty {
      self <<< " " + node.attributes.map({ $0.rawValue }).joined(separator: " ")
    }
    self <<< " '\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    self <<< " symbol='" <<< node.symbol?.name <<< "'"
    self <<< " scope='" <<< node.scope <<< "'"
    self <<< " inner_scope='" <<< node.innerScope <<< "'"
    withIndentation {
      if !node.directives.isEmpty {
        self <<< "\n" <<< indent <<< "(directives\n"
        withIndentation { visit(node.directives) }
        self <<< ")"
      }
      if !node.placeholders.isEmpty {
        self <<< "\n" <<< indent <<< "(placeholders\n"
        withIndentation {
          for placeholder in node.placeholders {
            self <<< indent <<< "(placeholder \(placeholder))"
            if placeholder != node.placeholders.last {
              self <<< "\n"
            }
          }
        }
        self <<< ")"
      }
      if !node.parameters.isEmpty {
        self <<< "\n" <<< indent <<< "(parameters\n"
        withIndentation { visit(node.parameters) }
        self <<< ")"
      }
      if let codomain = node.codomain {
        self <<< "\n" <<< indent <<< "(codomain\n"
        withIndentation { visit(codomain) }
        self <<< ")"
      }
      if let body = node.body {
        self <<< "\n" <<< indent <<< "(body\n"
        withIndentation { visit(body) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: ParamDecl) {
    self <<< indent <<< "(param_decl"
    self <<< " '\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    self <<< " symbol='" <<< node.symbol?.name <<< "'"
    self <<< " scope='" <<< node.scope <<< "'"
    withIndentation {
      if let typeAnnotation = node.typeAnnotation {
        self <<< "\n" <<< indent <<< "(type_annotation\n"
        withIndentation { visit(typeAnnotation) }
        self <<< ")"
      }
      if let value = node.defaultValue {
        self <<< "\n" <<< indent <<< "(default_value\n"
        withIndentation { visit(value) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: StructDecl) {
    self <<< indent <<< "(struct_decl"
    self <<< " '\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    self <<< " symbol='" <<< node.symbol?.name <<< "'"
    self <<< " scope='" <<< node.scope <<< "'"
    self <<< " inner_scope='" <<< node.innerScope <<< "'"
    withIndentation {
      if !node.placeholders.isEmpty {
        self <<< "\n" <<< indent <<< "(placeholders\n"
        withIndentation {
          for placeholder in node.placeholders {
            self <<< indent <<< "(placeholder \(placeholder))"
            if placeholder != node.placeholders.last {
              self <<< "\n"
            }
          }
        }
        self <<< ")"
      }
      self <<< "\n" <<< indent <<< "(body\n"
      withIndentation { visit(node.body) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: UnionNestedMemberDecl) {
    self <<< indent <<< "(union_nested_member_decl\n"
    withIndentation {
      visit(node.nominalTypeDecl)
    }
    self <<< ")"
  }

  public func visit(_ node: UnionDecl) {
    self <<< indent <<< "(union_decl"
    self <<< " '\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    self <<< " symbol='" <<< node.symbol?.name <<< "'"
    self <<< " scope='" <<< node.scope <<< "'"
    self <<< " inner_scope='" <<< node.innerScope <<< "'"
    withIndentation {
      if !node.placeholders.isEmpty {
        self <<< "\n" <<< indent <<< "(placeholders\n"
        withIndentation {
          for placeholder in node.placeholders {
            self <<< indent <<< "(placeholder \(placeholder))"
            if placeholder != node.placeholders.last {
              self <<< "\n"
            }
          }
        }
        self <<< ")"
      }
      self <<< "\n" <<< indent <<< "(body\n"
      withIndentation { visit(node.body) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: InterfaceDecl) {
    self <<< indent <<< "(interface_decl"
    self <<< " '\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    self <<< " symbol='" <<< node.symbol?.name <<< "'"
    self <<< " scope='" <<< node.scope <<< "'"
    self <<< " inner_scope='" <<< node.innerScope <<< "'"
    withIndentation {
      if !node.placeholders.isEmpty {
        self <<< "\n" <<< indent <<< "(placeholders\n"
        withIndentation {
          for placeholder in node.placeholders {
            self <<< indent <<< "(placeholder \(placeholder))"
            if placeholder != node.placeholders.last {
              self <<< "\n"
            }
          }
        }
        self <<< ")"
      }
      self <<< "\n" <<< indent <<< "(body\n"
      withIndentation { visit(node.body) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: QualTypeSign) {
    self <<< indent <<< "(qual_type_sign"
    if !node.qualifiers.isEmpty {
      self <<< " " + node.qualifiers.map({ $0.description }).sorted().joined(separator: " ")
    }
    if let signature = node.signature {
      self <<< "\n"
      withIndentation { visit(signature) }
    }
    self <<< ")"
  }

  public func visit(_ node: TypeIdent) {
    self <<< indent <<< "(type_identifier"
    self <<< " '\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    self <<< " scope='" <<< node.scope <<< "'"
    self <<< ")"
  }

  public func visit(_ node: FunSign) {
    self <<< indent <<< "(fun_sign"
    withIndentation {
      if !node.parameters.isEmpty {
        self <<< "\n" <<< indent <<< "(parameters\n"
        withIndentation { visit(node.parameters) }
        self <<< ")"
      }
      self <<< "\n" <<< indent <<< "(codomain\n"
      withIndentation { visit(node.codomain) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: ParamSign) {
    self <<< indent <<< "(param_sign"
    self <<< " '" <<< node.label <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(type_annotation\n"
      withIndentation { visit(node.typeAnnotation) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: Directive) {
    self <<< indent <<< "(directive"
    self <<< " '\(node.name)'"
    if !node.arguments.isEmpty {
      self <<< " " + node.arguments.joined(separator: " ")
    }
    self <<< ")"
  }

  public func visit(_ node: WhileLoop) {
    self <<< indent <<< "(while"
    withIndentation {
      self <<< "\n" <<< indent <<< "(condition\n"
      withIndentation { visit(node.condition) }
      self <<< ")\n" <<< indent <<< "(body\n"
      withIndentation { visit(node.body) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: BindingStmt) {
    self <<< indent <<< "(bind"
    withIndentation {
      self <<< "\n" <<< indent <<< "(lvalue\n"
      withIndentation { visit(node.lvalue) }
      self <<< ")"
      self <<< "\n" <<< indent <<< "(binding_operator \(node.op))\n"
      self <<< "\n" <<< indent <<< "(rvalue\n"
      withIndentation { visit(node.rvalue) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: ReturnStmt) {
    self <<< indent <<< "(return"
    if let (op, value) = node.binding {
      self <<< "\n" <<< indent <<< "(binding\n"
      withIndentation {
        self <<< indent <<< "(binding_operator \(op))\n"
        visit(value)
      }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: NullRef) {
    self <<< indent <<< "(nullref"
    self <<< " type='" <<< node.type <<< "'"
    self <<< ")"
  }

  public func visit(_ node: IfExpr) {
    self <<< indent <<< "(if"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(condition\n"
      withIndentation { visit(node.condition) }
      self <<< ")\n" <<< indent <<< "(then\n"
      withIndentation { visit(node.thenBlock) }
      self <<< ")"
      if let elseBlock = node.elseBlock {
        self <<< "\n" <<< indent <<< "(else\n"
        withIndentation { visit(elseBlock) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: LambdaExpr) {
    self <<< indent <<< "(lambda_expr"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      if !node.parameters.isEmpty {
        self <<< "\n" <<< indent <<< "(parameters\n"
        withIndentation { visit(node.parameters) }
        self <<< ")"
      }
      if let codomain = node.codomain {
        self <<< "\n" <<< indent <<< "(codomain\n"
        withIndentation { visit(codomain) }
        self <<< ")"
      }
      self <<< "\n" <<< indent <<< "(body\n"
      withIndentation { visit(node.body) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: CastExpr) {
    self <<< indent <<< "(cast_expr"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(operand\n"
      withIndentation { visit(node.operand) }
      self <<< ")"
      self <<< "\n" <<< indent <<< "(cast_type\n"
      withIndentation { visit(node.castType) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: BinExpr) {
    self <<< indent <<< "(bin_expr"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(left\n"
      withIndentation { visit(node.left) }
      self <<< ")"
      self <<< "\n" <<< indent <<< "(infix_operator \(node.op))"
      self <<< "\n" <<< indent <<< "(right\n"
      withIndentation { visit(node.right) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: UnExpr) {
    self <<< indent <<< "(un_expr"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(prefix_operator \(node.op))"
      self <<< "\n" <<< indent <<< "(operand\n"
      withIndentation { visit(node.operand) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: CallExpr) {
    self <<< indent <<< "(call"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(callee\n"
      withIndentation { visit(node.callee) }
      self <<< ")"
      if !node.arguments.isEmpty {
        self <<< "\n" <<< indent <<< "(arguments\n"
        withIndentation { visit(node.arguments) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: CallArg) {
    self <<< indent <<< "(call_arg"
    self <<< " '" <<< node.label <<< "'"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(binding_operator \(node.bindingOp))\n"
      visit(node.value)
    }
    self <<< ")"
  }

  public func visit(_ node: SubscriptExpr) {
    self <<< indent <<< "(subscript"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(callee\n"
      withIndentation { visit(node.callee) }
      self <<< ")"
      if !node.arguments.isEmpty {
        self <<< "\n" <<< indent <<< "(arguments\n"
        withIndentation { visit(node.arguments) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: SelectExpr) {
    self <<< indent <<< "(select"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      if let owner = node.owner {
        self <<< "\n" <<< indent <<< "(owner\n"
        withIndentation { visit(owner) }
        self <<< ")"
      }
      self <<< "\n" <<< indent <<< "(ownee\n"
      withIndentation { visit(node.ownee) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: ArrayLiteral) {
    self <<< indent <<< "(array_literal"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n"
      withIndentation { visit(node.elements) }
    }
    self <<< ")"
  }

  public func visit(_ node: SetLiteral) {
    self <<< indent <<< "(set_literal"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n"
      withIndentation { visit(node.elements) }
    }
    self <<< ")"
  }

  public func visit(_ node: MapLiteral) {
    self <<< indent <<< "(map_literal"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n"
      for (i, element) in node.elements.enumerated() {
        self <<< indent <<< "(map_literal_element\n"
        withIndentation {
          self <<< indent <<< "(key \(element.key))\n"
          self <<< indent <<< "(value"
          withIndentation { visit(element.value) }
          self <<< ")"
        }
        self <<< ")"
        if i < (node.elements.count - 1) {
          self <<< "\n"
        }
      }
    }
    self <<< ")"
  }

  public func visit(_ node: Ident) {
    self <<< indent <<< "(identifier"
    self <<< " '\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    self <<< " scope='" <<< node.scope <<< "'"
    self <<< ")"
  }

  public func visit(_ node: Literal<Bool>) {
    self <<< indent <<< "(bool_literal \(node.value)"
    self <<< " type='" <<< node.type <<< "'"
    self <<< ")"
  }

  public func visit(_ node: Literal<Int>) {
    self <<< indent <<< "(int_literal \(node.value)"
    self <<< " type='" <<< node.type <<< "'"
    self <<< ")"
  }

  public func visit(_ node: Literal<Double>) {
    self <<< indent <<< "(float_literal \(node.value)"
    self <<< " type='" <<< node.type <<< "'"
    self <<< ")"
  }

  public func visit(_ node: Literal<String>) {
    self <<< indent <<< "(string_literal \"\(node.value)\""
    self <<< " type='" <<< node.type <<< "'"
    self <<< ")"
  }

  public func visit(_ nodes: [Node]) {
    for node in nodes {
      visit(node)
      if node !== nodes.last {
        self <<< "\n"
      }
    }
  }

  fileprivate func withIndentation(body: () -> Void) {
    level += 1
    body()
    level -= 1
  }

  @discardableResult
  fileprivate static func <<< <T>(dumper: ASTDumper, item: T) -> ASTDumper {
    dumper.outputStream.write(String(describing: item))
    return dumper
  }

  @discardableResult
  fileprivate static func <<< <T>(dumper: ASTDumper, item: T?) -> ASTDumper {
    dumper.outputStream.write(item.map({ String(describing: $0) }) ?? "_")
    return dumper
  }

}
