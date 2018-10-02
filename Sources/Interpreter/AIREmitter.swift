import AST
import Utils

/// Emits the Anzen Intermediate Representation of a unit (i.e. module).
///
/// - Note: Modules processed by this visitor are expected to have been type-checked.
public class AIREmitter: ASTVisitor {

  public init(builder: AIRBuilder) {
    self.builder = builder
  }

  public func visit(_ node: ModuleDecl) throws {
    // Create the `main` function if the unit is the program's entry.
    if builder.unit.isEntry {
      let mainType = builder.context.getFunctionType(from: [], to: NothingType.get)
      let main = builder.unit.getFunction(name: "main", type: mainType)
      main.appendBlock(name: "entry")
      builder.currentBlock = main.blocks.first?.value
    }

    try emitBlock(statements: node.statements)

    if builder.unit.isEntry {
      let symbols = node.statements.compactMap { ($0 as? NamedDecl)?.symbol }
      for sym in symbols.reversed() {
        if let value = registers[sym] as? NewRefInst {
          builder.buildDrop(value: value)
        }
        registers[sym] = nil
      }
    }
  }

  public func visit(_ node: Block) throws {
    try emitBlock(statements: node.statements)
  }

  private func emitBlock(statements: [Node]) throws {
    // Process all statements.
    for statement in statements {
      try visit(statement)

      // Call expressions may be used as a statement, without being bound to any l-value.
      if let value = stack.pop() as? NewRefInst {
        guard statement is CallExpr && stack.isEmpty
          else { fatalError("unconsumed r-value(s)") }
        builder.buildDrop(value: value)
      }
    }
  }

  public func visit(_ node: PropDecl) throws {
    let ref = builder.buildRef(type: node.type!)
    registers[node.symbol!] = ref

    if let (op, value) = node.initialBinding {
      try visit(value)
      builder.build(assignment: op, source: stack.pop()!, target: ref)
    }
  }

  public func visit(_ node: FunDecl) throws {
    // Retrieve the function object.
    let fnType = node.type as! FunctionType
    let fn = builder.unit.getFunction(name: mangle(symbol: node.symbol!), type: fnType)
    assert(fn.blocks.isEmpty, "AIR for \(node) already emitted")

    if let body = node.body {
      // Create the entry point of the function.
      let previousBlock = builder.currentBlock
      fn.appendBlock(name: "entry")
      builder.currentBlock = fn.blocks.first?.value

      // Create the function parameters.
      for parameter in node.parameters {
        let paramref = AIRParameter(type: node.type!, name: builder.currentBlock!.nextName())
        registers[parameter.symbol!] = paramref
      }

      try visit(body)

      // Restore the insertion point.
      builder.currentBlock = previousBlock

      // FIXME: Handle generic parameters.
      // FIXME: Handle closures.
      // FIXME: Drop explicitly owned argument references.
    }
  }

  public func visit(_ node: BindingStmt) throws {
    try visit(node.lvalue)
    try visit(node.rvalue)
    let rvalue = stack.pop()!
    let lvalue = stack.pop() as! NewRefInst
    builder.build(assignment: node.op, source: rvalue, target: lvalue)
  }

  public func visit(_ node: ReturnStmt) throws {
    // FIXME: Drop local references, except the return value (if any).

    if let value = node.value {
      try visit(value)
      builder.buildReturn(value: stack.pop()!)
    } else {
      builder.buildReturn()
    }
  }

  public func visit(_ node: Ident) throws {
    // Look for the node's symbol in the accessible scopes.
    if let value = registers[node.symbol!] {
      stack.push(value)
      return
    }

    // If the symbol isn't declared yet, it should refer to a hoisted function or type declaration.
    // Other cases may not happen, as they would correspond to an `undefined symbol` error, which
    // would have been detected during the semantic analysis.
    if let type = node.symbol!.type as? FunctionType {
      let fn = builder.unit.getFunction(name: mangle(symbol: node.symbol!), type: type)
      registers[node.symbol!] = fn
      stack.push(fn)
      return
    }

    // FIXME: Hoist type declarations.
    fatalError()
  }

  public func visit(_ node: CallExpr) throws {
    let callee = builder.buildRef(type: node.callee.type!)
    try visit(node.callee)
    builder.buildBind(source: stack.pop()!, target: callee)

    let argrefs = try node.arguments.map { (argument) -> NewRefInst in
      let argref = builder.buildRef(type: argument.type!)
      try visit(argument.value)
      builder.build(assignment: argument.bindingOp, source: stack.pop()!, target: argref)
      return argref
    }

    let apply = builder.buildApply(callee: callee, arguments: argrefs, type: node.type!)
    stack.push(apply)

    for argref in argrefs {
      // FIXME: Don't drop arguments for which the callee takes ownership.
      builder.buildDrop(value: argref)
    }
  }

  public func visit(_ node: Literal<Int>) {
    stack.push(AIRLiteral(value: node.value, type: node.type!))
  }

  public var builder: AIRBuilder

  private var stack: Stack<AIRValue> = []
  private var registers: [Symbol: AIRValue] = [:]

}
