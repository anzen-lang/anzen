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

  private var stack : Stack<AIRValue> = []
  private var locals: Stack<[Symbol: AIRValue]> = []
  private var frames: Stack<Frame> = []

  /// The (unspecialized) generic functions available.
  private var genericFunctions: [Symbol: FunDecl] = [:]
  /// The specialization requests.
  private var specRequests: [(symbol: Symbol, type: FunctionType)] = []
  /// Mapping used to emit the specialization of a generic function.
  internal var bindings: [PlaceholderType: TypeBase] = [:]

  public func visit(_ node: ModuleDecl) throws {
    // Create the `main` function if the unit is supposed to be the program's entry.
    if builder.unit.isMain {
      let mainFnType = getFunctionType(from: [], to: .nothing)
      let mainFn = builder.unit.getFunction(name: "main", type: mainFnType)
      mainFn.appendBlock(label: "entry")
      builder.currentBlock = mainFn.blocks.first?.value
      locals.push([:])
    }

    try emitBlock(statements: node.statements)

    if builder.unit.isMain {
      locals.pop()
    }

    // Emit the AIR code for all generic specializations.
    var done: [Symbol: [TypeBase]] = [:]
    while let req = specRequests.popLast() {
      // Skip the request if it was already done.
      done[req.symbol] = done[req.symbol] ?? []
      guard !done[req.symbol]!.contains(req.type)
        else { continue }

      // Emit the specialized function.
      guard let decl = genericFunctions[req.symbol]
        else { fatalError("\(req.symbol) is not a known generic function") }
      try emitFunction(decl: decl, withType: req.type)
      done[req.symbol]?.append(req.type)
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
      if stack.pop() is MakeRefInst {
        guard statement is CallExpr && stack.isEmpty
          else { fatalError("unconsumed r-value(s)") }
      }
    }
  }

  private func emitFunction(decl: FunDecl, withType type: FunctionType? = nil) throws {
    // Specialize the type of the function symbol, if necessary.
    let aznTy: FunctionType
    if type != nil {
      assert(bindings.isEmpty)
      aznTy = type!
      guard specializes(
        lhs: aznTy, rhs: decl.symbol!.type!, in: builder.context, bindings: &bindings)
      else { fatalError("type mismatch") }
    } else {
      aznTy = decl.symbol!.type as! FunctionType
    }

    // Get the AIR type of the function.
    var airTy = getFunctionType(of: aznTy)

    // Constructors and methods shall not have closures.
    assert(
      decl.captures.isEmpty || (decl.kind != .constructor && decl.kind != .method),
      "constructor and methods shall not have closures")

    if decl.symbol!.isMethod {
      // Methods (and destructors?) are static functions that take the self symbol and return the
      // "actual" method as a closure.
      let symbols = decl.innerScope!.symbols["self"]!
      assert(symbols.count == 1)
      let methTy = airTy.codomain as! AIRFunctionType
      airTy = getFunctionType(
        from: [getType(of: symbols[0].type!)] + methTy.domain,
        to: methTy.codomain)
    } else if !decl.captures.isEmpty {
      // If the function captures symbols, we need to emit a context-free version of the it, which
      // gets the captured values as parameters. This boils down to extending the domain.
      let additional = decl.captures.map { getType(of: $0.type!) }
      airTy = getFunctionType(from: additional + airTy.domain, to: airTy.codomain)
    }

    // Retrieve the function object.
    let mangledName = mangle(symbol: decl.symbol!, withType: aznTy)
    let fn = builder.unit.getFunction(name: mangledName, type: airTy)
    assert(fn.blocks.isEmpty, "AIR for \(decl) with type \(airTy) already emitted")

    if !decl.captures.isEmpty {
      // Create the function closure.
      // Note that arguments are captured by reference in the current frame.
      locals.top![decl.symbol!] = builder.buildPartialApply(
        function: fn,
        arguments: decl.captures.map { locals.top![$0]! },
        type: airTy)
    }

    if let body = decl.body {
      // Create the entry point of the function.
      let previousBlock = builder.currentBlock
      fn.appendBlock(label: "entry")
      builder.currentBlock = fn.blocks.first?.value

      // Set up the local register map.
      locals.push([:])

      let selfSym: Symbol? = decl.innerScope?.symbols["self"]?[0]
      if decl.kind == .constructor {
        assert(selfSym != nil, "missing symbol for 'self' in constructor")
        locals.top![selfSym!] = builder.buildAlloc(type: airTy.codomain, id: 0)
      } else if decl.symbol!.isMethod {
        assert(selfSym != nil, "missing symbol for 'self' in method")
        locals.top![selfSym!] = AIRParameter(
          type: getType(of: selfSym!.type!),
          id: builder.currentBlock!.nextRegisterID())
      }

      // Create the function parameters.
      let parameterSymbols = decl.captures + decl.parameters.map({ $0.symbol! })
      for sym in parameterSymbols {
        let paramref = AIRParameter(
          type: getType(of: sym.type!),
          id: builder.currentBlock!.nextRegisterID())
        locals.top![sym] = paramref
      }

      // Set up the function frame.
      let exitBlock = fn.appendBlock(label: "exit")
      let returnReg = aznTy.codomain != NothingType.get
        ? builder.buildMakeRef(type: airTy.codomain)
        : nil
      frames.push(Frame(exitBlock: exitBlock, returnRegister: returnReg))

      try visit(body)

      // The last instruction of the current block must be an unconditional jump to the exit block,
      // which is not necessarily the case for function that may return implicitly, such as
      // constructors and non-returning functions.
      let lastInst = builder.currentBlock!.instructions.last as? JumpInst
      if lastInst?.label != exitBlock.label {
        builder.buildJump(label: exitBlock.label)
      }
      builder.currentBlock = frames.top!.exitBlock

      // Emit the function return.
      if decl.kind == .constructor {
        builder.buildReturn(value: locals.top![selfSym!])
      } else if aznTy.codomain != NothingType.get {
        builder.buildReturn(value: frames.top!.returnRegister)
      } else {
        builder.buildReturn()
      }

      // Restore the insertion point.
      builder.currentBlock = previousBlock
      locals.pop()
      frames.pop()
    }

    bindings = [:]
  }

  public func visit(_ node: PropDecl) throws {
    let ref = builder.buildMakeRef(type: getType(of: node.type!))
    locals.top![node.symbol!] = ref

    if let (op, value) = node.initialBinding {
      try visit(value)
      builder.build(assignment: op, source: stack.pop()!, target: ref)
    }
  }

  public func visit(_ node: FunDecl) throws {
    let aznTy = node.type as! FunctionType
    guard aznTy.placeholders.isEmpty else {
      // AIR generation for generic functions is delayed until they are specialized in context.
      genericFunctions[node.symbol!] = node
      return
    }

    try emitFunction(decl: node)
  }

  public func visit(_ node: StructDecl) throws {
    // Only visit function declarations.
    try visit(node.body.statements.filter({ $0 is FunDecl }))
  }

  public func visit(_ node: BindingStmt) throws {
    try visit(node.lvalue)
    try visit(node.rvalue)
    let rvalue = stack.pop()!
    let lvalue = stack.pop() as! AIRRegister
    builder.build(assignment: node.op, source: rvalue, target: lvalue)
  }

  public func visit(_ node: ReturnStmt) throws {
    guard let frame = frames.top
      else { fatalError("not in a function") }
    if let value = node.value {
      try visit(value)
      builder.buildCopy(source: stack.pop()!, target: frame.returnRegister!)
    }
    builder.buildJump(label: frame.exitBlock.label)
  }

  public func visit(_ node: IfExpr) throws {
    guard let currentFn = builder.currentBlock?.function
      else { fatalError("not in a function") }
    let yes   = currentFn.insertBlock(after: builder.currentBlock!, label: "yes")
    let no    = currentFn.insertBlock(after: yes, label: "no")
    let after = currentFn.insertBlock(after: no, label: "after")

    try visit(node.condition)
    builder.buildBranch(condition: stack.pop()!, thenLabel: yes.label, elseLabel: no.label)

    builder.currentBlock = yes
    try visit(node.thenBlock)
    builder.buildJump(label: after.label)

    builder.currentBlock = no
    try node.elseBlock.map { try visit($0) }
    builder.buildJump(label: after.label)

    builder.currentBlock = after
  }

  public func visit(_ node: CallExpr) throws {
    let callee = builder.buildMakeRef(type: getType(of: node.callee.type!))
    try visit(node.callee)
    builder.buildBind(source: stack.pop()!, target: callee)

    let argrefs = try node.arguments.map { (argument) -> MakeRefInst in
      let argref = builder.buildMakeRef(type: getType(of: argument.type!))
      try visit(argument.value)
      builder.build(assignment: argument.bindingOp, source: stack.pop()!, target: argref)
      return argref
    }

    let apply = builder.buildApply(
      callee: callee,
      arguments: argrefs,
      type: getType(of: node.type!))
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
      let uncurriedTy = getFunctionType(
        from: (methTy.domain + fnTy.domain).map({ getType(of: $0.type) }),
        to: getType(of: fnTy.codomain))

      // Create the partial application of the uncurried function.
      let uncurried = builder.unit.getFunction(
        name: mangle(symbol: node.ownee.symbol!),
        type: uncurriedTy)
      let partial = builder.buildPartialApply(
        function: uncurried,
        arguments: [stack.pop()!],
        type: getType(of: node.type!))
      stack.push(partial)
      return
    }

    if owner.type is NominalType {
      // If the ownee isn't a method, but the owner's a nominal type, then the expression should
      // "extract" a field from the owner.
      let airTy = getType(of: owner.type!) as! AIRStructType
      guard let index = airTy.members.firstIndex(where: { $0.key == node.ownee.name })
        else { fatalError("\(node.ownee.name) is not a stored property of \(owner.type!)") }
      let extract = builder.buildExtract(
        from: stack.pop()!,
        index: index,
        type: getType(of: node.type!))
      stack.push(extract)
      return
    }

    // FIXME: Distinguish between stored and computed properties.
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
    if let fnTy = (node.type as? FunctionType) {
      // NOTE: Functions that capture symbols can't be hoisted, as the capture may happen after the
      // function call otherwise. Therefore, we don't have to handle partial applications (a.k.a.
      // function closures) here.
      let fn = builder.unit.getFunction(
        name: mangle(symbol: node.symbol!, withType: node.type),
        type: getFunctionType(of: fnTy))

      // If the function symbol is generic, register the specialization request.
      if !(node.symbol?.type as! FunctionType).placeholders.isEmpty {
        specRequests.append((symbol: node.symbol!, type: fnTy))
      }

      // locals.top![node.symbol!] = fn
      stack.push(fn)
      return
    }

    // FIXME: Hoist type declarations.
    fatalError()
  }

  public func visit(_ node: Literal<Bool>) {
    stack.push(AIRConstant(value: node.value))
  }

  public func visit(_ node: Literal<Int>) {
    stack.push(AIRConstant(value: node.value))
  }

  public func visit(_ node: Literal<Double>) {
    stack.push(AIRConstant(value: node.value))
  }

  public func visit(_ node: Literal<String>) {
    stack.push(AIRConstant(value: node.value))
  }

}

private struct Frame {

  let exitBlock: InstructionBlock
  let returnRegister: MakeRefInst?

}
