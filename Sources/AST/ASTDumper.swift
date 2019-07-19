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

  public func visit(_ node: ModuleDecl) throws {
    self <<< indent <<< "(module_decl"
    self <<< " id='" <<< node.id?.qualifiedName <<< "'"
    self <<< " inner_scope='" <<< node.innerScope <<< "'"

    if !node.statements.isEmpty {
      self <<< "\n"
      withIndentation { try visit(node.statements) }
    }
    self <<< ")\n"
  }

  public func visit(_ node: Block) throws {
    self <<< indent <<< "(block"
    self <<< " inner_scope='" <<< node.innerScope <<< "'"

    if !node.statements.isEmpty {
      withIndentation {
        self <<< "\n"
        withIndentation { try visit(node.statements) }
      }
    }
    self <<< ")"
  }

  public func visit(_ node: PropDecl) throws {
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
        withIndentation { try visit(typeAnnotation) }
        self <<< ")"
      }
      if let (op, value) = node.initialBinding {
        self <<< "\n" <<< indent <<< "(initial_binding\n"
        withIndentation {
          self <<< indent <<< "(binding_operator \(op))\n"
          try visit(value)
        }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: FunDecl) throws {
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
        withIndentation { try visit(node.parameters) }
        self <<< ")"
      }
      if let codomain = node.codomain {
        self <<< "\n" <<< indent <<< "(codomain\n"
        withIndentation { try visit(codomain) }
        self <<< ")"
      }
      if let body = node.body {
        self <<< "\n" <<< indent <<< "(body\n"
        withIndentation { try visit(body) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: ParamDecl) throws {
    self <<< indent <<< "(param_decl"
    self <<< " '\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    self <<< " symbol='" <<< node.symbol?.name <<< "'"
    self <<< " scope='" <<< node.scope <<< "'"
    withIndentation {
      if let typeAnnotation = node.typeAnnotation {
        self <<< "\n" <<< indent <<< "(type_annotation\n"
        withIndentation { try visit(typeAnnotation) }
        self <<< ")"
      }
      if let value = node.defaultValue {
        self <<< "\n" <<< indent <<< "(default_value\n"
        withIndentation { try visit(value) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: StructDecl) throws {
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
      withIndentation { try visit(node.body) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: InterfaceDecl) throws {
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
      withIndentation { try visit(node.body) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: QualTypeSign) throws {
    self <<< indent <<< "(qual_type_sign"
    if !node.qualifiers.isEmpty {
      self <<< " " + node.qualifiers.map({ $0.description }).sorted().joined(separator: " ")
    }
    if let signature = node.signature {
      self <<< "\n"
      withIndentation { try visit(signature) }
    }
    self <<< ")"
  }

  public func visit(_ node: TypeIdent) throws {
    self <<< indent <<< "(type_identifier"
    self <<< " '\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    self <<< " scope='" <<< node.scope <<< "'"
    self <<< ")"
  }

  public func visit(_ node: FunSign) throws {
    self <<< indent <<< "(fun_sign"
    withIndentation {
      if !node.parameters.isEmpty {
        self <<< "\n" <<< indent <<< "(parameters\n"
        withIndentation { try visit(node.parameters) }
        self <<< ")"
      }
      self <<< "\n" <<< indent <<< "(codomain\n"
      withIndentation { try visit(node.codomain) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: ParamSign) throws {
    self <<< indent <<< "(param_sign"
    self <<< " '" <<< node.label <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(type_annotation\n"
      withIndentation { try visit(node.typeAnnotation) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: WhileLoop) throws {
    self <<< indent <<< "(while"
    withIndentation {
      self <<< "\n" <<< indent <<< "(condition\n"
      withIndentation { try visit(node.condition) }
      self <<< ")\n" <<< indent <<< "(body\n"
      withIndentation { try visit(node.body) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: BindingStmt) throws {
    self <<< indent <<< "(bind"
    withIndentation {
      self <<< "\n" <<< indent <<< "(lvalue\n"
      withIndentation { try visit(node.lvalue) }
      self <<< ")"
      self <<< "\n" <<< indent <<< "(binding_operator \(node.op))\n"
      self <<< "\n" <<< indent <<< "(rvalue\n"
      withIndentation { try visit(node.rvalue) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: ReturnStmt) throws {
    self <<< indent <<< "(return"
    if let (op, value) = node.binding {
      self <<< "\n" <<< indent <<< "(binding\n"
      withIndentation {
        self <<< indent <<< "(binding_operator \(op))\n"
        try visit(value)
      }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: IfExpr) throws {
    self <<< indent <<< "(if"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(condition\n"
      withIndentation { try visit(node.condition) }
      self <<< ")\n" <<< indent <<< "(then\n"
      withIndentation { try visit(node.thenBlock) }
      self <<< ")"
      if let elseBlock = node.elseBlock {
        self <<< "\n" <<< indent <<< "(else\n"
        withIndentation { try visit(elseBlock) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: LambdaExpr) throws {
    self <<< indent <<< "(lambda_expr"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      if !node.parameters.isEmpty {
        self <<< "\n" <<< indent <<< "(parameters\n"
        withIndentation { try visit(node.parameters) }
        self <<< ")"
      }
      if let codomain = node.codomain {
        self <<< "\n" <<< indent <<< "(codomain\n"
        withIndentation { try visit(codomain) }
        self <<< ")"
      }
      self <<< "\n" <<< indent <<< "(body\n"
      withIndentation { try visit(node.body) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: CastExpr) throws {
    self <<< indent <<< "(cast_expr"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(operand\n"
      withIndentation { try visit(node.operand) }
      self <<< ")"
      self <<< "\n" <<< indent <<< "(cast_type\n"
      withIndentation { try visit(node.castType) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: BinExpr) throws {
    self <<< indent <<< "(bin_expr"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(left\n"
      withIndentation { try visit(node.left) }
      self <<< ")"
      self <<< "\n" <<< indent <<< "(infix_operator \(node.op))"
      self <<< "\n" <<< indent <<< "(right\n"
      withIndentation { try visit(node.right) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: UnExpr) throws {
    self <<< indent <<< "(un_expr"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(prefix_operator \(node.op))"
      self <<< "\n" <<< indent <<< "(operand\n"
      withIndentation { try visit(node.operand) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: CallExpr) throws {
    self <<< indent <<< "(call"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(callee\n"
      withIndentation { try visit(node.callee) }
      self <<< ")"
      if !node.arguments.isEmpty {
        self <<< "\n" <<< indent <<< "(arguments\n"
        withIndentation { try visit(node.arguments) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: CallArg) throws {
    self <<< indent <<< "(call_arg"
    self <<< " '" <<< node.label <<< "'"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(binding_operator \(node.bindingOp))\n"
      try visit(node.value)
    }
    self <<< ")"
  }

  public func visit(_ node: SubscriptExpr) throws {
    self <<< indent <<< "(subscript"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(callee\n"
      withIndentation { try visit(node.callee) }
      self <<< ")"
      if !node.arguments.isEmpty {
        self <<< "\n" <<< indent <<< "(arguments\n"
        withIndentation { try visit(node.arguments) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: SelectExpr) throws {
    self <<< indent <<< "(select"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      if let owner = node.owner {
        self <<< "\n" <<< indent <<< "(owner\n"
        withIndentation { try visit(owner) }
        self <<< ")"
      }
      self <<< "\n" <<< indent <<< "(ownee\n"
      withIndentation { try visit(node.ownee) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: ArrayLiteral) throws {
    self <<< indent <<< "(array_literal"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n"
      withIndentation { try visit(node.elements) }
    }
    self <<< ")"
  }

  public func visit(_ node: SetLiteral) throws {
    self <<< indent <<< "(set_literal"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n"
      withIndentation { try visit(node.elements) }
    }
    self <<< ")"
  }

  public func visit(_ node: MapLiteral) throws {
    self <<< indent <<< "(map_literal"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n"
      for (i, element) in node.elements.enumerated() {
        self <<< indent <<< "(map_literal_element\n"
        withIndentation {
          self <<< indent <<< "(key \(element.key))\n"
          self <<< indent <<< "(value"
          withIndentation { try visit(element.value) }
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

  public func visit(_ node: Ident) throws {
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

  public func visit(_ nodes: [Node]) throws {
    for node in nodes {
      try visit(node)
      if node != nodes.last {
        self <<< "\n"
      }
    }
  }

  fileprivate func withIndentation(body: () throws -> Void) {
    level += 1
    try! body()
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
