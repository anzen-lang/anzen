import Utils

public struct ASTPrinter: ASTVisitor {

  public init(in console: Console = Console.err, includeType: Bool = false) {
    self.console = console
    self.includeType = includeType
  }

  /// The output stream.
  public let console: Console
  /// Whether or not include the type of the nodes in the output.
  public let includeType: Bool

  /// The indentation level of the printer.
  private var indent: Int = 0
  /// The "newline" value.
  private var newline: String { return "\n" + String(repeating: " ", count: indent) }

  public mutating func visit(_ node: ModuleDecl) throws {
    for statement in node.statements {
      try visit(statement)
      writeln("")
    }
  }

  public mutating func visit(_ node: Block) throws {
    indent += 2
    writeln("{")
    for statement in node.statements {
      write(String(repeating: " ", count: indent))
      try visit(statement)
      writeln("")
    }
    indent -= 2
    writeln("}")
  }

  public mutating func visit(_ node: PropDecl) throws {
    if !node.attributes.isEmpty {
      write(str(items: node.attributes, separator: " ") + " ")
    }
    write(node.reassignable ? "var " : "let ", in: .magenta)
    write(node.name)

    if includeType { comment(":\(str(node.type))") }

    if let annotation = node.typeAnnotation {
      write(": ")
      try visit(annotation)
    }
    if let (op, value) = node.initialBinding {
      write(" \(op) ")
      try visit(value)
    }
  }

  public mutating func visit(_ node: FunDecl) throws {
    if !node.attributes.isEmpty {
      write(str(items: node.attributes, separator: " ") + " ")
    }
    write("fun ", in: .magenta)
    write(node.name, in: .cyan)

    if includeType { comment(":\(str(node.type)) ") }

    if !node.placeholders.isEmpty {
      write("<\(str(items: node.placeholders))>")
    }
    write("(")
    for parameter in node.parameters {
      try visit(parameter)
      if parameter != node.parameters.last {
        write(", ")
      }
    }
    write(")")
    if let codomain = node.codomain {
      write(" -> ")
      try visit(codomain)
    }
    if let body = node.body {
      write(" ")
      try visit(body)
    }
  }

  public mutating func visit(_ node: ParamDecl) throws {
    write(str(node.label))
    if node.label != node.name {
      write(" \(node.name)")
    }

    if includeType { comment(":\(str(node.type))") }

    if let annotation = node.typeAnnotation {
      write(": ")
      try visit(annotation)
    }
    if let value = node.defaultValue {
      write(" = ")
      try visit(value)
    }
  }

  public mutating func visit(_ node: StructDecl) throws {
    write("struct ", in: .magenta)
    write(node.name, in: .yellow)

    if includeType { comment(":\(str(node.type))") }

    if !node.placeholders.isEmpty {
      write("<\(str(items: node.placeholders))>")
    }
    write(" ")
    try visit(node.body)
  }

  public mutating func visit(_ node: InterfaceDecl) throws {
    write("interface ", in: .magenta)
    write(node.name, in: .yellow)

    if includeType { comment(":\(str(node.type))") }

    if !node.placeholders.isEmpty {
      write("<\(str(items: node.placeholders))>")
    }
    write(" ")
    try visit(node.body)
  }

  public mutating func visit(_ node: QualSign) throws {
    write(str(items: node.qualifiers, separator: " "))
    if let signature = node.signature {
      if !node.qualifiers.isEmpty {
        write(" ")
      }
      try visit(signature)
    }
  }

  public mutating func visit(_ node: FunSign) throws {
    write("(")
    for parameter in node.parameters {
      try visit(parameter)
      if parameter != node.parameters.last {
        write(", ")
      }
    }
    write(") -> ")
    try visit(node.codomain)
  }

  public mutating func visit(_ node: ParamSign) throws {
    write(str(node.label) + " ")
    try visit(node.typeAnnotation)
  }

  public mutating func visit(_ node: BindingStmt) throws {
    write(node.lvalue)
    write(" \(node.op) ")
    write(node.rvalue)
  }

  public mutating func visit(_ node: ReturnStmt) throws {
    write("return", in: .magenta)
    if let value = node.value {
      write(" ")
      try visit(value)
    }
  }

  public mutating func visit(_ node: IfExpr) throws {
    write("if ", in: .magenta)
    try visit(node.condition)
    write(" ")
    try visit(node.thenBlock)
    if let elseBlock = node.elseBlock {
      write(" else ")
      try visit(elseBlock)
    }
  }

  public mutating func visit(_ node: BinExpr) throws {
    try visit(node.left)
    write(" \(node.op) ")
    try visit(node.right)
  }

  public mutating func visit(_ node: UnExpr) throws {
    write("\(node.op) ")
    try visit(node.operand)
  }

  public mutating func visit(_ node: CallExpr) throws {
    try visit(node.callee)
    write("(")
    for argument in node.arguments {
      try visit(argument)
      if argument != node.arguments.last {
        write(", ")
      }
    }
    write(")")
  }

  public mutating func visit(_ node: CallArg) throws {
    if let label = node.label {
      write("\(label) \(node.bindingOp) ")
    }
    try visit(node.value)
  }

  public mutating func visit(_ node: SubscriptExpr) throws {
    try visit(node.callee)
    write("[")
    for argument in node.arguments {
      try visit(argument)
      if argument != node.arguments.last {
        write(", ")
      }
    }
    write("]")
  }

  public mutating func visit(_ node: SelectExpr) throws {
    if let owner = node.owner {
      try visit(owner)
    }
    write(".")
    try visit(node.ownee)
  }

  public mutating func visit(_ node: LambdaExpr) throws {
    write("fun (")
    for parameter in node.parameters {
      try visit(parameter)
      if parameter != node.parameters.last {
        write(", ")
      }
    }
    write(")")
    if let codomain = node.codomain {
      write(" -> ")
      try visit(codomain)
    }
    write(" ")
    try visit(node.body)
  }

  public mutating func visit(_ node: Ident) throws {
    write(node.name)

    if includeType { comment(":\(str(node.type))") }

    if !node.specializations.isEmpty {
      write("<")
      for (key, value) in node.specializations {
        write("\(key) = ")
        try visit(value)
        write(", ")
      }
      write(">")
    }
  }

  public mutating func visit(_ node: ArrayLiteral) throws {
    write("[")
    for element in node.elements {
      try visit(element)
      writeln(",")
    }
    write("]")
  }

  public mutating func visit(_ node: SetLiteral) throws {
    write("{")
    for element in node.elements {
      try visit(element)
      writeln(",")
    }
    write("}")
  }

  public mutating func visit(_ node: MapLiteral) throws {
    write("{")
    for (key, value) in node.elements {
      write("\(key): ")
      try visit(value)
      writeln(",")
    }
    write("}")
  }

  public func visit(_ node: Literal<Bool>) {
    write(node.value, in: .green)
  }

  public func visit(_ node: Literal<Int>) {
    write(node.value, in: .green)
  }

  public func visit(_ node: Literal<Double>) {
    write(node.value, in: .green)
  }

  public func visit(_ node: Literal<String>) {
    write("\"\(node.value)\"", in: .green)
  }

  private func write(
    _ item: Any,
    in style: Console.Style = .default,
    terminator: String = "")
  {
    console.print(item, in: style, terminator: terminator)
  }

  private func writeln(_ item: Any, in style: Console.Style = .default) {
    console.print(item, in: style)
  }

  private func comment(_ text: String, terminator: String = "") {
    console.print("\(text)", in: .dimmed, terminator: terminator)
  }

}

private func str<T>(_ item: T) -> String {
  return String(describing: item)
}

private func str<S>(items: S, separator: String = ", ") -> String where S: Sequence {
  return items.map(str).joined(separator: separator)
}

private func str<T>(_ item: T?) -> String {
  return item.map { String(describing: $0) } ?? "_"
}
