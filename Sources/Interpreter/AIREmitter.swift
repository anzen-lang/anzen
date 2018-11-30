import AST
import Utils

/// Emits the Anzen Intermediate Representation of a unit (i.e. module).
///
/// - Note: Modules processed by this visitor are expected to have been type-checked.
public class AIREmitter: ASTVisitor {

  public init(builder: AIRBuilder) {
    self.builder = builder
  }

  public var builder: AIRBuilder

  private var stack: Stack<AIRValue> = []

  private var locals: Stack<[Symbol: AIRValue]> = []

  public func visit(_ node: ModuleDecl) throws {
    // Create the `main` function if the unit is supposed to be the program's entry.
    if builder.unit.isMain {
      let mainType = builder.context.getFunctionType(from: [], to: NothingType.get)
      let main = builder.unit.getFunction(name: "main", type: mainType)
      main.appendBlock(label: "entry")
      builder.currentBlock = main.blocks.first?.value
      locals.push([:])
    }

    try emitBlock(statements: node.statements)

    if builder.unit.isMain {
      locals.pop()
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
      if stack.pop() is AllocInst {
        guard statement is CallExpr && stack.isEmpty
          else { fatalError("unconsumed r-value(s)") }
      }
    }
  }

  public func visit(_ node: PropDecl) throws {
    let ref = builder.buildRef(type: node.type!)
    locals.top![node.symbol!] = ref

    if let (op, value) = node.initialBinding {
      try visit(value)
      builder.build(assignment: op, source: stack.pop()!, target: ref)
    }
  }

  public func visit(_ node: FunDecl) throws {
    // Get the type of the declared function.
    var fnType = node.type as! FunctionType

    if !node.captures.isEmpty {
      // If the function captures symbols, we need to emit a context-free version of the it, which
      // gets the captured values as parameters. This boils down to extending the domain.
      let additional = node.captures.map { Parameter(label: nil, type: $0.type!) }
      fnType = builder.context.getFunctionType(
        from: additional + fnType.domain, to: fnType.codomain, placeholders: fnType.placeholders)
    }

    // Retrieve the function object.
    let fn = builder.unit.getFunction(name: mangle(symbol: node.symbol!), type: fnType)
    assert(fn.blocks.isEmpty, "AIR for \(node) already emitted")

    if let body = node.body {
      // Create the entry point of the function.
      let previousBlock = builder.currentBlock
      fn.appendBlock(label: "entry")
      builder.currentBlock = fn.blocks.first?.value

      // Set up the local register mapping.
      locals.push([:])

      // Create the function parameters.
      let parameterSymbols = node.captures + node.parameters.map({ $0.symbol! })
      for sym in parameterSymbols {
        let paramref = AIRParameter(type: sym.type!, name: builder.currentBlock!.nextRegisterName())
        locals.top![sym] = paramref
      }

      try visit(body)

      // Restore the insertion point.
      builder.currentBlock = previousBlock
      locals.pop()

      // FIXME: Handle closures.
      // The idea would be to assign they symbol in the local regster mapping with a partial
      // application that embeds the closure, pretty much the same way SIL does.
    }

    // NOTE: Generic functions are represented unspecialized in AIR, so that borrow checking can be
    // performed only once, no matter the number of times the function is specialized.
  }

  public func visit(_ node: BindingStmt) throws {
    try visit(node.lvalue)
    try visit(node.rvalue)
    let rvalue = stack.pop()!
    let lvalue = stack.pop() as! AllocInst
    builder.build(assignment: node.op, source: rvalue, target: lvalue)
  }

  public func visit(_ node: ReturnStmt) throws {
    if let value = node.value {
      try visit(value)
      builder.buildReturn(value: stack.pop()!)
    } else {
      builder.buildReturn()
    }
  }

  public func visit(_ node: IfExpr) throws {
    guard let currentFn = builder.currentBlock?.function
      else { fatalError("not in a function") }
    let thenIB = currentFn.appendBlock(label: "then")
    let elseIB = currentFn.appendBlock(label: "else")
    let afterIB = currentFn.appendBlock(label: "after")

    try visit(node.condition)
    builder.buildBranch(condition: stack.pop()!, thenLabel: thenIB.label, elseLabel: elseIB.label)

    builder.currentBlock = thenIB
    try visit(node.thenBlock)
    builder.buildJump(label: afterIB.label)

    builder.currentBlock = elseIB
    try node.elseBlock.map { try visit($0) }
    builder.buildJump(label: afterIB.label)

    builder.currentBlock = afterIB
  }

  public func visit(_ node: CallExpr) throws {
    let callee = builder.buildRef(type: node.callee.type!)
    try visit(node.callee)
    builder.buildBind(source: stack.pop()!, target: callee)

    let argrefs = try node.arguments.map { (argument) -> AllocInst in
      let argref = builder.buildRef(type: argument.type!)
      try visit(argument.value)
      builder.build(assignment: argument.bindingOp, source: stack.pop()!, target: argref)
      return argref
    }

    let apply = builder.buildApply(callee: callee, arguments: argrefs, type: node.type!)
    stack.push(apply)

    // TODO: There's probably a way to optimize calls to built-in functions, so that we don't
    // need to create partial applications for built-in operators. A promising lead would be to
    // check if the callee's a select whose owner has a built-in type.
  }

  public func visit(_ node: SelectExpr) throws {
    guard let owner = node.owner
      else { fatalError("Support for implicit not implemented") }
    try visit(owner)

    if node.ownee.symbol!.isMethod {
      // Methods have types of the form `(_: Self) -> FnTy`, so they must be loaded as a partial
      // application of an uncurried function, taking `self` as its first parameter.
      guard let methTy = node.ownee.symbol!.type as? FunctionType
        else { fatalError() }
      guard let fnTy = methTy.codomain as? FunctionType
        else { fatalError() }
      let uncurriedTy = builder.context.getFunctionType(
        from: methTy.domain + fnTy.domain,
        to: fnTy.codomain)

      // Create the partial application of the uncurried function.
      let uncurried = builder.unit.getFunction(
        name: mangle(symbol: node.ownee.symbol!),
        type: uncurriedTy)
      let partial = builder.buildPartialApply(
        function: uncurried,
        arguments: [stack.pop()!],
        type: node.type!)
      stack.push(partial)
      return
    }

    fatalError("TODO")
  }

  public func visit(_ node: Ident) throws {
    // Look for the node's symbol in the accessible scopes.
    if let value = locals.top![node.symbol!] {
      stack.push(value)
      return
    }

    // The symbol might not be declared yet if it refers to a hoisted type or function. Otherwise,
    // an `undefined symbol` error would have been detected during semantic analysis.
    if let functionType = (node.symbol!.type as? FunctionType) {
      // NOTE: Functions that capture symbols can't be hoisted, as the capture may happen after the
      // function call otherwise. Therefore, we don't have to handle partial applications (a.k.a.
      // function closures) here.
      let fn = builder.unit.getFunction(
        name: mangle(symbol: node.symbol!),
        type: functionType)

      locals.top![node.symbol!] = fn
      stack.push(fn)
      return
    }

    // FIXME: Hoist type declarations.
    fatalError()
  }

  public func visit(_ node: Literal<Bool>) {
    stack.push(AIRLiteral(value: node.value, type: node.type!))
  }

  public func visit(_ node: Literal<Int>) {
    stack.push(AIRLiteral(value: node.value, type: node.type!))
  }

  public func visit(_ node: Literal<Double>) {
    stack.push(AIRLiteral(value: node.value, type: node.type!))
  }

  public func visit(_ node: Literal<String>) {
    stack.push(AIRLiteral(value: node.value, type: node.type!))
  }

}
