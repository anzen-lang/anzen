import AST
import Utils

/// Emits the Anzen's Intermediate Representation of a module.
public func emitUnit(_ module: ModuleDecl, context: ASTContext, isMain: Bool = false) -> AIRUnit {
  let unit = AIRUnit(name: module.id?.qualifiedName ?? "__air_unit")
  let builder = AIRBuilder(unit: unit, context: context)

  var requestedImpl: [(FunDecl, FunctionType)] = []
  var processedImpl: [Symbol: [TypeBase]] = [:]

  if isMain {
    // Create the `main` function if the unit is supposed to be the program's entry.
    let mainFnType = unit.getFunctionType(from: [], to: .nothing)
    let mainFn = builder.unit.getFunction(name: "main", type: mainFnType)
    mainFn.appendBlock(label: "entry")
    let exitBlock = mainFn.appendBlock(label: "exit")

    let emitter = AIREmitter(builder: builder, function: mainFn)
    try! emitter.visit(module.statements)

    builder.buildJump(label: exitBlock.label)
    builder.currentBlock = exitBlock
    builder.buildReturn()

    requestedImpl = emitter.requestedImpl
  } else {
    fatalError("TODO")
  }

  while let (decl, type) = requestedImpl.popLast() {
    guard processedImpl[decl.symbol!]?.first(where: { $0 == type }) == nil
      else { continue }

    var bindings: [PlaceholderType: TypeBase] = [:]
    guard specializes(lhs: type, rhs: decl.type!, in: context, bindings: &bindings)
      else { fatalError("type mismatch") }

    let emitter = AIREmitter(
      builder: builder,
      decl: decl,
      type: type,
      bindings: bindings)
    requestedImpl.append(contentsOf: emitter.requestedImpl)
  }

  return unit
}

/// AST visitor for emitting AIR instructions.
class AIREmitter: ASTVisitor {

  let builder: AIRBuilder
  private var stack: Stack<AIRValue> = []
  private var locals: [Symbol: AIRValue] = [:]
  private var retReg: AIRRegister? = nil

  /// The type bindings.
  var bindings: [PlaceholderType: TypeBase]

  /// The environment in which thick higher-order functions are declared.
  private var thinkFunctionEnvironment: [Symbol: [Symbol: AIRValue]] = [:]

  /// The functions for which an implementation should be provided.
  var requestedImpl: [(FunDecl, FunctionType)] = []

  init(
    builder: AIRBuilder,
    function: AIRFunction,
    bindings: [PlaceholderType: TypeBase] = [:])
  {
    self.builder = builder
    self.builder.currentBlock = function.blocks.values.first
    self.bindings = bindings
  }

  init(
    builder: AIRBuilder,
    decl: FunDecl,
    type: FunctionType,
    bindings: [PlaceholderType: TypeBase] = [:])
  {
    self.builder = builder
    self.bindings = bindings

    // Get the AIR type of the function.
    var fnType = emitType(of: type)

    if decl.kind == .method || decl.kind == .destructor {
      // Methods and destructors are lowered into static functions that take the self symbol and
      // return the "actual" method as a closure.
      let symbols = decl.innerScope!.symbols["self"]!
      assert(symbols.count == 1)
      let methTy = fnType.codomain as! AIRFunctionType
      fnType = builder.unit.getFunctionType(
        from: fnType.domain + methTy.domain,
        to: methTy.codomain)
    } else if !decl.captures.isEmpty {
      // If the function captures symbols, we need to emit a context-free version of the it, which
      // gets the captured values as parameters. This boils down to extending the domain.
      let additional = decl.captures.map { emitType(of: $0.type!) }
      fnType = builder.unit.getFunctionType(from: additional + fnType.domain, to: fnType.codomain)
    }

    // Retrieve the function object.
    let fn = builder.unit.getFunction(
      name: mangle(symbol: decl.symbol!, withType: type),
      type: fnType)

    guard fn.blocks.isEmpty
      else { return }

    if let body = decl.body {
      builder.currentBlock = fn.appendBlock(label: "entry")
      let exitBlock = fn.appendBlock(label: "exit")

      // Handle self in constructor and methods.
      let selfSym: Symbol? = decl.innerScope?.symbols["self"]?[0]
      if decl.kind == .constructor {
        assert(selfSym != nil, "missing symbol for 'self' in constructor")
        locals[selfSym!] = builder.buildAlloc(type: fnType.codomain, id: 0)
      } else if decl.symbol!.isMethod {
        assert(selfSym != nil, "missing symbol for 'self' in method")
        locals[selfSym!] = AIRParameter(
          type: fnType.domain[0],
          id: builder.currentBlock!.nextRegisterID())
      }

      // Create the function parameters.
      for sym in decl.captures {
        let paramref = AIRParameter(
          type: emitType(of: sym.type!), id: builder.currentBlock!.nextRegisterID())
        locals[sym] = paramref
      }
      for (paramDecl, paramSign) in zip(decl.parameters, type.domain) {
        let paramref = AIRParameter(
          type: emitType(of: paramSign.type),
          id: builder.currentBlock!.nextRegisterID())
        locals[paramDecl.symbol!] = paramref
      }

      retReg = type.codomain != NothingType.get
        ? builder.buildMakeRef(type: fnType.codomain)
        : nil

      try! visit(body)

      // The last instruction of the current block must be an unconditional jump to the exit block.
      let lastInst = builder.currentBlock!.instructions.last as? JumpInst
      if lastInst?.label != exitBlock.label {
        builder.buildJump(label: exitBlock.label)
      }
      builder.currentBlock = exitBlock

      // Emit the function return.
      if decl.kind == .constructor {
        builder.buildReturn(value: locals[selfSym!])
      } else if type.codomain != NothingType.get {
        builder.buildReturn(value: retReg!)
      } else {
        builder.buildReturn()
      }
    }
  }

  func visit(_ node: PropDecl) throws {
    let ref = builder.buildMakeRef(type: emitType(of: node.type!))
    locals[node.symbol!] = ref

    if let (op, value) = node.initialBinding {
      try visit(value)
      builder.build(assignment: op, source: stack.pop()!, target: ref)
    }
  }

  func visit(_ node: FunDecl) throws {
    // Thick functions must have their environment stored at the time of their declaration.
    if !node.captures.isEmpty {
      // Constructors and methods shall not have closures.
      assert(
        node.kind != .constructor && node.kind != .method,
        "constructor and methods shall not have closures")

      // Implementation note:
      //
      // Higher-order functions are defunctionalized, and represented as partial applications to
      // deal with captured references. Therefore the declaration's environment has to be saved
      // so that the captured references can be injected into the partial application later on.
      //
      // Notice that for now all captures are assumed by alias. Other strategies will require
      // assigment instructions to be emitted here.

      let env = Dictionary(uniqueKeysWithValues: node.captures.map {($0, locals[$0]!) })
      thinkFunctionEnvironment[node.symbol!] = env
    }
  }

  func visit(_ node: StructDecl) throws {
  }

  func visit(_ node: WhileLoop) throws {
    guard let currentFn = builder.currentBlock?.function
      else { fatalError("not in a function") }

    let test = currentFn.insertBlock(after: builder.currentBlock!, label: "test")
    let cont = currentFn.insertBlock(after: test, label: "cont")
    let post = currentFn.insertBlock(after: cont, label: "post")

    builder.buildJump(label: test.label)
    builder.currentBlock = test
    try visit(node.condition)
    builder.buildBranch(condition: stack.pop()!, thenLabel: cont.label, elseLabel: post.label)

    builder.currentBlock = cont
    try visit(node.body)
    builder.buildJump(label: test.label)

    builder.currentBlock = post
  }

  func visit(_ node: BindingStmt) throws {
    try visit(node.lvalue)
    let lvalue = stack.pop() as! AIRRegister
    try visit(node.rvalue)
    let rvalue = stack.pop()!
    builder.build(assignment: node.op, source: rvalue, target: lvalue)
  }

  func visit(_ node: ReturnStmt) throws {
    guard let currentFn = builder.currentBlock?.function
      else { fatalError("not in a function") }

    if let value = node.value {
      try visit(value)
      builder.buildCopy(source: stack.pop()!, target: retReg!)
    }

    builder.buildJump(label: currentFn.blocks.values.last!.label)
  }

  func visit(_ node: IfExpr) throws {
    guard let currentFn = builder.currentBlock?.function
      else { fatalError("not in a function") }

    let then = currentFn.insertBlock(after: builder.currentBlock!, label: "then")
    let els_ = currentFn.insertBlock(after: then, label: "else")
    let post = currentFn.insertBlock(after: els_, label: "post")

    try visit(node.condition)
    builder.buildBranch(condition: stack.pop()!, thenLabel: then.label, elseLabel: els_.label)

    builder.currentBlock = then
    try visit(node.thenBlock)
    builder.buildJump(label: post.label)

    builder.currentBlock = els_
    if let elseBlock = node.elseBlock {
      try visit(elseBlock)
    }
    builder.buildJump(label: post.label)

    builder.currentBlock = post
  }

  func visit(_ node: CastExpr) throws {
    try visit(node.operand)
    let castTy = emitType(of: node.type!)
    let unsafeCast = builder.buildUnsafeCast(source: stack.pop()!, as: castTy)
    stack.push(unsafeCast)
  }

  func visit(_ node: CallExpr) throws {
    let callee = builder.buildMakeRef(type: emitType(of: node.callee.type!))
    try visit(node.callee)
    builder.buildBind(source: stack.pop()!, target: callee)

    let argrefs = try node.arguments.map { (argument) -> MakeRefInst in
      let argref = builder.buildMakeRef(type: emitType(of: argument.type!))
      try visit(argument.value)
      builder.build(assignment: argument.bindingOp, source: stack.pop()!, target: argref)
      return argref
    }

    let apply = builder.buildApply(
      callee: callee,
      arguments: argrefs,
      type: emitType(of: node.type!))
    stack.push(apply)

    // TODO: There's probably a way to optimize calls to built-in functions, so that we don't
    // need to create partial applications for built-in operators. A promising lead would be to
    // check if the callee's a select whose owner has a built-in type.
  }

  func visit(_ node: SelectExpr) throws {
    guard let owner = node.owner
      else { fatalError("Support for implicit not implemented") }
    try visit(owner)

    // FIXME: What about static methods?
    if node.ownee.symbol!.isMethod {
      // Methods have types of the form `(_: Self) -> FnTy`, so they must be loaded as a partial
      // application of an uncurried function, taking `self` as its first parameter.
      let anzenType = builder.context.getFunctionType(
        from: [Parameter(label: nil, type: node.owner!.type!)],
        to: node.ownee.type!)

      let fnTy = emitType(of: node.ownee.type!) as! AIRFunctionType
      let uncurriedTy = emitType(
        from: [emitType(of: owner.type!)] + fnTy.domain,
        to: fnTy.codomain)

      // Create the partial application of the uncurried function.
      let uncurried = builder.unit.getFunction(
        name: mangle(symbol: node.ownee.symbol!, withType: anzenType),
        type: uncurriedTy)
      let partial = builder.buildPartialApply(
        function: uncurried,
        arguments: [stack.pop()!],
        type: emitType(of: node.type!))
      stack.push(partial)

      let decl = builder.context.declarations[node.ownee.symbol!]
      requestedImpl.append((decl as! FunDecl, anzenType))
      return
    }

    // FIXME: Distinguish between stored and computed properties.

    // If the ownee isn't a method, but the owner's a nominal type, then the expression should
    // "extract" a field from the owner.
    guard let airTy = emitType(of: owner.type!) as? AIRStructType
      else { fatalError("\(node.ownee.name) is not a stored property of \(owner.type!)") }
    guard let index = airTy.members.firstIndex(where: { $0.key == node.ownee.name })
      else { fatalError("\(node.ownee.name) is not a stored property of \(owner.type!)") }
    let extract = builder.buildExtract(
      from: stack.pop()!,
      index: index,
      type: emitType(of: node.type!))
    stack.push(extract)
  }

  public func visit(_ node: Ident) throws {
    // Look for the node's symbol in the accessible scopes.
    if let value = locals[node.symbol!] {
      stack.push(value)
      return
    }

    // If the identifier's symbol isn't declared yet, it either refers to a function or a type
    // constructor (an `undefined symbol` error would have raised during semantic analysis).
    guard let aznTy = (node.type as? FunctionType)
      else { fatalError() }

    let airTy = emitType(of: aznTy)
    if let env = thinkFunctionEnvironment[node.symbol!] {
      // If the identifier refers to the name of a thick function, we've to create a closure. As
      // thick functions aren't hoisted, we can assume to environment to have already been set.
      let additional = env.keys.map { emitType(of: $0.type!) }
      let fnTy = emitType(from: additional + airTy.domain, to: airTy.codomain)
      let fn = builder.unit.getFunction(
        name: mangle(symbol: node.symbol!, withType: aznTy),
        type: fnTy)
      let val = builder.buildPartialApply(
        function: fn,
        arguments: Array(env.values),
        type: fnTy)
      stack.push(val)
    } else {
      // If the identifier refers to the name of a thin function, then we just need to use the
      // corresponding AIR function value.
      let fn = builder.unit.getFunction(
        name: mangle(symbol: node.symbol!, withType: aznTy),
        type: airTy)
      stack.push(fn)
    }

    let decl = builder.context.declarations[node.symbol!]
    requestedImpl.append((decl as! FunDecl, aznTy))
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
