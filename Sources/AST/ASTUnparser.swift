import Utils
import SystemKit

public final class ASTUnparser: ASTVisitor {

  public init(console: Console = System.err, includeType: Bool = false) {
    self.console = console
    self.includeType = includeType
  }

  /// The output stream.
  public let console: Console
  /// Whether or not include the type of the nodes in the output.
  public let includeType: Bool

  private var stack: Stack<String> = []
  private var isVisitingCallee: Bool = false

  public func visit(_ node: ModuleDecl) throws {
    for statement in node.statements {
      try visit(statement)
      console.print(stack.pop()!)
    }
    assert(stack.isEmpty)
  }

  public func visit(_ node: Block) throws {
    let statements = try node.statements.map { (statement) -> String in
      try visit(statement)
      return indent(stack.pop()!)
    }
    stack.push("{\n\(str(items: statements, separator: "\n"))\n}")
  }

  public func visit(_ node: PropDecl) throws {
    var repr = ""
    if !node.attributes.isEmpty {
      repr += node.attributes.map({ $0.rawValue.styled("magenta") }).joined(separator: " ")
      repr += " "
    }
    repr += (node.attributes.contains(.reassignable) ? "var " : "let ").styled("magenta")
    repr += node.name

    if includeType {
      repr += ":\(str(node.type))".styled("dimmed")
    }

    if let annotation = node.typeAnnotation {
      try visit(annotation)
      repr += ": \(stack.pop()!)"
    }
    if let (op, value) = node.initialBinding {
      try visit(value)
      repr += " \(op) \(stack.pop()!)"
    }

    stack.push(repr)
  }

  public func visit(_ node: FunDecl) throws {
    var repr = ""
    if !node.directives.isEmpty {
      let directives = try node.directives.map { (directive) -> String in
        try visit(directive)
        return stack.pop()!
      }
      repr += "\(str(items: directives, separator: " "))"
      repr += "\n"
    }
    if !node.attributes.isEmpty {
      repr += node.attributes.map({ $0.rawValue.styled("magenta") }).joined(separator: " ")
      repr += " "
    }
    if node.kind == .constructor || node.kind == .destructor {
      repr += node.name.styled("magenta")
    } else {
      repr += StyledString("{fun:magenta} {\(node.name):cyan}")
    }

    if includeType {
      repr += ":\(str(node.type))".styled("dimmed")
    }

    if !node.placeholders.isEmpty {
      let placeholders = node.placeholders.map({ $0.styled("yellow") })
      repr += "<\(str(items: placeholders))>"
    }

    let parameters = try node.parameters.map { (parameter) -> String in
      try visit(parameter)
      return stack.pop()!
    }
    repr += "(\(str(items: parameters)))"

    if let codomain = node.codomain {
      try visit(codomain)
      repr += " -> \(stack.pop()!)"
    }

    if let body = node.body {
      try visit(body)
      repr += " \(stack.pop()!)"
    }

    stack.push(repr)
  }

  public func visit(_ node: ParamDecl) throws {
    var repr = str(node.label)
    if node.label != node.name {
      repr += " \(node.name)"
    }

    if includeType {
      repr += ":\(str(node.type))".styled("dimmed")
    }

    if let annotation = node.typeAnnotation {
      try visit(annotation)
      repr += ": \(stack.pop()!)"
    }
    if let value = node.defaultValue {
      try visit(value)
      repr += " = \(stack.pop()!)"
    }

    stack.push(repr)
  }

  public func visit(_ node: StructDecl) throws {
    var repr = StyledString("{struct:magenta} {\(node.name):yellow}").description

    if includeType {
      repr += ":\(str(node.type))".styled("dimmed")
    }

    if !node.placeholders.isEmpty {
      let placeholders = node.placeholders.map({ $0.styled("yellow") })
      repr += "<\(str(items: placeholders))>"
    }
    try visit(node.body)
    repr += " \(stack.pop()!)"
    stack.push(repr)
  }

//  public func visit(_ node: InterfaceDecl) throws {
//    write("interface ", styled: "magenta")
//    write(node.name, styled: "yellow")
//
//    if includeType { comment(":\(str(node.type))") }
//
//    if !node.placeholders.isEmpty {
//      write("<\(str(items: node.placeholders))>")
//    }
//    write(" ")
//    try visit(node.body)
//  }
//
//  public func visit(_ node: QualSign) throws {
//    write(str(items: node.qualifiers, separator: " "))
//    if let signature = node.signature {
//      if !node.qualifiers.isEmpty {
//        write(" ")
//      }
//      try visit(signature)
//    }
//  }

  public func visit(_ node: TypeIdent) throws {
    var repr = node.name.styled("yellow")
    if includeType {
      repr += ":\(str(node.type))".styled("dimmed")
    }

    if !node.specializations.isEmpty {
      var args: [String] = []
      for (key, value) in node.specializations {
        try visit(value)
        args.append("\(key) = \(stack.pop()!)")
      }
      repr += "<\(str(items: args))>"
    }

    stack.push(repr)
  }

//  public func visit(_ node: FunSign) throws {
//    write("(")
//    for parameter in node.parameters {
//      try visit(parameter)
//      if parameter != node.parameters.last {
//        write(", ")
//      }
//    }
//    write(") -> ")
//    try visit(node.codomain)
//  }
//
//  public func visit(_ node: ParamSign) throws {
//    write(str(node.label) + " ")
//    try visit(node.typeAnnotation)
//  }

  public func visit(_ node: Directive) throws {
    var repr = "#".styled("magenta") + node.name.styled("magenta")
    if !node.arguments.isEmpty {
      repr += "(\(str(items: node.arguments)))"
    }

    stack.push(repr)
  }

  public func visit(_ node: WhileLoop) throws {
    var repr = StyledString("{while:magenta}").description
    try visit(node.condition)
    repr += " \(stack.pop()!)"

    try visit(node.body)
    repr += " \(stack.pop()!)"

    stack.push(repr)
  }

  public func visit(_ node: BindingStmt) throws {
    try visit(node.rvalue)
    try visit(node.lvalue)
    stack.push("\(stack.pop()!) \(node.op) \(stack.pop()!)")
  }

  public func visit(_ node: ReturnStmt) throws {
    var repr = "return".styled("magenta")
    if let (op, value) = node.binding {
      try visit(value)
      repr += " \(op) \(stack.pop()!)"
    }
    stack.push(repr)
  }

  public func visit(_ node: IfExpr) throws {
    var repr = StyledString("{if:magenta}").description
    try visit(node.condition)
    repr += " \(stack.pop()!)"

    try visit(node.thenBlock)
    repr += " \(stack.pop()!)"

    if let elseBlock = node.elseBlock {
      try visit(elseBlock)
      repr += " else \(stack.pop()!)"
    }

    stack.push(repr)
  }

  public func visit(_ node: CastExpr) throws {
    try visit(node.operand)
    try visit(node.castType)
    stack.push("\(stack.pop()!) as \(stack.pop()!)")
  }

  public func visit(_ node: BinExpr) throws {
    try visit(node.right)
    try visit(node.left)
    stack.push("\(stack.pop()!) \(node.op) \(stack.pop()!)")
  }

//  public func visit(_ node: UnExpr) throws {
//    write("\(node.op) ")
//    try visit(node.operand)
//  }

  public func visit(_ node: CallExpr) throws {
    let wasVisitinCallee = isVisitingCallee
    isVisitingCallee = true
    try visit(node.callee)
    var repr = stack.pop()!
    isVisitingCallee = wasVisitinCallee

    let arguments = try node.arguments.map { (argument) -> String in
      try visit(argument)
      return stack.pop()!
    }
    repr += "(\(str(items: arguments)))"

    stack.push(repr)
  }

  public func visit(_ node: CallArg) throws {
    try visit(node.value)
    if let label = node.label {
      stack.push("\(label) \(node.bindingOp) \(stack.pop()!)")
    }
  }

//  public func visit(_ node: SubscriptExpr) throws {
//    try visit(node.callee)
//    write("[")
//    for argument in node.arguments {
//      try visit(argument)
//      if argument != node.arguments.last {
//        write(", ")
//      }
//    }
//    write("]")
//  }
//
//  public func visit(_ node: LambdaExpr) throws {
//    write("fun (")
//    for parameter in node.parameters {
//      try visit(parameter)
//      if parameter != node.parameters.last {
//        write(", ")
//      }
//    }
//    write(")")
//    if let codomain = node.codomain {
//      write(" -> ")
//      try visit(codomain)
//    }
//    write(" ")
//    try visit(node.body)
//  }

  public func visit(_ node: SelectExpr) throws {
    var repr = "."
    if let owner = node.owner {
      try visit(owner)
      repr = stack.pop()! + repr
    }
    try visit(node.ownee)
    repr += stack.pop()!

    stack.push(repr)
  }

  public func visit(_ node: Ident) throws {
    var repr = node.name
    if isVisitingCallee {
      repr = repr.styled("cyan")
    }

    if includeType {
      repr += ":\(str(node.type))".styled("dimmed")
    }

    if !node.specializations.isEmpty {
      var args: [String] = []
      for (key, value) in node.specializations {
        try visit(value)
        args.append("\(key) = \(stack.pop()!)")
      }
      repr += "<\(str(items: args))>"
    }

    stack.push(repr)
  }

//  public func visit(_ node: ArrayLiteral) throws {
//    write("[")
//    for element in node.elements {
//      try visit(element)
//      writeln(",")
//    }
//    write("]")
//  }
//
//  public func visit(_ node: SetLiteral) throws {
//    write("{")
//    for element in node.elements {
//      try visit(element)
//      writeln(",")
//    }
//    write("}")
//  }
//
//  public func visit(_ node: MapLiteral) throws {
//    write("{")
//    for (key, value) in node.elements {
//      write("\(key): ")
//      try visit(value)
//      writeln(",")
//    }
//    write("}")
//  }

  public func visit(_ node: Literal<Bool>) {
    stack.push(String(node.value).styled("green"))
  }

  public func visit(_ node: Literal<Int>) {
    stack.push(String(node.value).styled("green"))
  }

  public func visit(_ node: Literal<Double>) {
    stack.push(String(node.value).styled("green"))
  }

  public func visit(_ node: Literal<String>) {
    stack.push("\"\(node.value)\"".styled("green"))
  }

  private func comment(_ text: String) -> String {
    return "\(text)".styled("dimmed")
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

private func indent(_ string: String) -> String {
  return string
    .split(separator: "\n")
    .map  ({ "  " + $0 })
    .joined(separator: "\n")
}
