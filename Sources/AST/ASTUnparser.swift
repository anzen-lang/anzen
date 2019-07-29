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

  public func visit(_ node: ModuleDecl) {
    for statement in node.statements {
      visit(statement)
      console.print(stack.pop()!)
    }
    assert(stack.isEmpty)
  }

  public func visit(_ node: Block) {
    let statements = node.statements.map { (statement) -> String in
      visit(statement)
      return indent(stack.pop()!)
    }
    stack.push("{\n\(str(items: statements, separator: "\n"))\n}")
  }

  public func visit(_ node: PropDecl) {
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
      visit(annotation)
      repr += ": \(stack.pop()!)"
    }
    if let (op, value) = node.initialBinding {
      visit(value)
      repr += " \(op) \(stack.pop()!)"
    }

    stack.push(repr)
  }

  public func visit(_ node: FunDecl) {
    var repr = ""
    if !node.directives.isEmpty {
      let directives = node.directives.map { (directive) -> String in
        visit(directive)
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

    let parameters = node.parameters.map { (parameter) -> String in
      visit(parameter)
      return stack.pop()!
    }
    repr += "(\(str(items: parameters)))"

    if let codomain = node.codomain {
      visit(codomain)
      repr += " -> \(stack.pop()!)"
    }

    if let body = node.body {
      visit(body)
      repr += " \(stack.pop()!)"
    }

    stack.push(repr)
  }

  public func visit(_ node: ParamDecl) {
    var repr = str(node.label)
    if node.label != node.name {
      repr += " \(node.name)"
    }

    if includeType {
      repr += ":\(str(node.type))".styled("dimmed")
    }

    if let annotation = node.typeAnnotation {
      visit(annotation)
      repr += ": \(stack.pop()!)"
    }
    if let value = node.defaultValue {
      visit(value)
      repr += " = \(stack.pop()!)"
    }

    stack.push(repr)
  }

  public func visit(_ node: StructDecl) {
    var repr = StyledString("{struct:magenta} {\(node.name):yellow}").description

    if includeType {
      repr += ":\(str(node.type))".styled("dimmed")
    }

    if !node.placeholders.isEmpty {
      let placeholders = node.placeholders.map({ $0.styled("yellow") })
      repr += "<\(str(items: placeholders))>"
    }
    visit(node.body)
    repr += " \(stack.pop()!)"
    stack.push(repr)
  }

  public func visit(_ node: UnionNestedMemberDecl) {
    var repr = StyledString("{case:magenta}").description
    visit(node.nominalTypeDecl)
    repr += " \(stack.pop()!)"
    stack.push(repr)
  }

  public func visit(_ node: UnionDecl) {
    var repr = StyledString("{union:magenta} {\(node.name):yellow}").description

    if includeType {
      repr += ":\(str(node.type))".styled("dimmed")
    }

    if !node.placeholders.isEmpty {
      let placeholders = node.placeholders.map({ $0.styled("yellow") })
      repr += "<\(str(items: placeholders))>"
    }
    visit(node.body)
    repr += " \(stack.pop()!)"
    stack.push(repr)
  }

//  public func visit(_ node: InterfaceDecl) {
//    write("interface ", styled: "magenta")
//    write(node.name, styled: "yellow")
//
//    if includeType { comment(":\(str(node.type))") }
//
//    if !node.placeholders.isEmpty {
//      write("<\(str(items: node.placeholders))>")
//    }
//    write(" ")
//    visit(node.body)
//  }
//
//  public func visit(_ node: QualSign) {
//    write(str(items: node.qualifiers, separator: " "))
//    if let signature = node.signature {
//      if !node.qualifiers.isEmpty {
//        write(" ")
//      }
//      visit(signature)
//    }
//  }

  public func visit(_ node: TypeIdent) {
    var repr = node.name.styled("yellow")
    if includeType {
      repr += ":\(str(node.type))".styled("dimmed")
    }

    if !node.specializations.isEmpty {
      var args: [String] = []
      for (key, value) in node.specializations {
        visit(value)
        args.append("\(key) = \(stack.pop()!)")
      }
      repr += "<\(str(items: args))>"
    }

    stack.push(repr)
  }

//  public func visit(_ node: FunSign) {
//    write("(")
//    for parameter in node.parameters {
//      visit(parameter)
//      if parameter != node.parameters.last {
//        write(", ")
//      }
//    }
//    write(") -> ")
//    visit(node.codomain)
//  }
//
//  public func visit(_ node: ParamSign) {
//    write(str(node.label) + " ")
//    visit(node.typeAnnotation)
//  }

  public func visit(_ node: Directive) {
    var repr = "#".styled("magenta") + node.name.styled("magenta")
    if !node.arguments.isEmpty {
      repr += "(\(str(items: node.arguments)))"
    }

    stack.push(repr)
  }

  public func visit(_ node: WhileLoop) {
    var repr = StyledString("{while:magenta}").description
    visit(node.condition)
    repr += " \(stack.pop()!)"

    visit(node.body)
    repr += " \(stack.pop()!)"

    stack.push(repr)
  }

  public func visit(_ node: BindingStmt) {
    visit(node.rvalue)
    visit(node.lvalue)
    stack.push("\(stack.pop()!) \(node.op) \(stack.pop()!)")
  }

  public func visit(_ node: ReturnStmt) {
    var repr = "return".styled("magenta")
    if let (op, value) = node.binding {
      visit(value)
      repr += " \(op) \(stack.pop()!)"
    }
    stack.push(repr)
  }

  public func visit(_ node: NullRef) {
    stack.push("nullref".styled("magenta"))
  }

  public func visit(_ node: IfExpr) {
    var repr = StyledString("{if:magenta}").description
    visit(node.condition)
    repr += " \(stack.pop()!)"

    visit(node.thenBlock)
    repr += " \(stack.pop()!)"

    if let elseBlock = node.elseBlock {
      visit(elseBlock)
      repr += " else \(stack.pop()!)"
    }

    stack.push(repr)
  }

  public func visit(_ node: CastExpr) {
    visit(node.operand)
    visit(node.castType)
    stack.push("\(stack.pop()!) as \(stack.pop()!)")
  }

  public func visit(_ node: BinExpr) {
    visit(node.right)
    visit(node.left)
    stack.push("\(stack.pop()!) \(node.op) \(stack.pop()!)")
  }

//  public func visit(_ node: UnExpr) {
//    write("\(node.op) ")
//    visit(node.operand)
//  }

  public func visit(_ node: CallExpr) {
    let wasVisitinCallee = isVisitingCallee
    isVisitingCallee = true
    visit(node.callee)
    var repr = stack.pop()!
    isVisitingCallee = wasVisitinCallee

    let arguments = node.arguments.map { (argument) -> String in
      visit(argument)
      return stack.pop()!
    }
    repr += "(\(str(items: arguments)))"

    stack.push(repr)
  }

  public func visit(_ node: CallArg) {
    visit(node.value)
    if let label = node.label {
      stack.push("\(label) \(node.bindingOp) \(stack.pop()!)")
    }
  }

//  public func visit(_ node: SubscriptExpr) {
//    visit(node.callee)
//    write("[")
//    for argument in node.arguments {
//      visit(argument)
//      if argument != node.arguments.last {
//        write(", ")
//      }
//    }
//    write("]")
//  }
//
//  public func visit(_ node: LambdaExpr) {
//    write("fun (")
//    for parameter in node.parameters {
//      visit(parameter)
//      if parameter != node.parameters.last {
//        write(", ")
//      }
//    }
//    write(")")
//    if let codomain = node.codomain {
//      write(" -> ")
//      visit(codomain)
//    }
//    write(" ")
//    visit(node.body)
//  }

  public func visit(_ node: SelectExpr) {
    var repr = "."
    if let owner = node.owner {
      visit(owner)
      repr = stack.pop()! + repr
    }
    visit(node.ownee)
    repr += stack.pop()!

    stack.push(repr)
  }

  public func visit(_ node: Ident) {
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
        visit(value)
        args.append("\(key) = \(stack.pop()!)")
      }
      repr += "<\(str(items: args))>"
    }

    stack.push(repr)
  }

//  public func visit(_ node: ArrayLiteral) {
//    write("[")
//    for element in node.elements {
//      visit(element)
//      writeln(",")
//    }
//    write("]")
//  }
//
//  public func visit(_ node: SetLiteral) {
//    write("{")
//    for element in node.elements {
//      visit(element)
//      writeln(",")
//    }
//    write("}")
//  }
//
//  public func visit(_ node: MapLiteral) {
//    write("{")
//    for (key, value) in node.elements {
//      write("\(key): ")
//      visit(value)
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
