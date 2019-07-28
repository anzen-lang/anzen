import AST
import Utils

/// AST visitor for emitting AIR instructions.
class AIREmitter: ASTVisitor {

  private let builder: AIRBuilder

  private var locals: [Symbol: AIRValue] = [:]

  private let returnRegister: AIRRegister?

  private var stack: Stack<AIRValue> = []

  /// The type emitter.
  private var typeEmitter: TypeEmitter

  /// The environment in which thick higher-order functions are declared.
  private var thinkFunctionEnvironment: [Symbol: [Symbol: AIRValue]] = [:]

  /// The functions for which an implementation should be provided.
  var requestedImpl: [(FunDecl, FunctionType)] = []

  init(
    builder: AIRBuilder,
    locals: [Symbol: AIRValue],
    returnRegister: AIRRegister?,
    typeEmitter: TypeEmitter)
  {
    self.builder = builder
    self.locals = locals
    self.returnRegister = returnRegister
    self.typeEmitter = typeEmitter
  }

  func visit(_ node: PropDecl) throws {
    let reference = builder.buildMakeRef(
      type: typeEmitter.emitType(of: node.type!),
      debugInfo: node.debugInfo)
    locals[node.symbol!] = reference

    if let (op, value) = node.initialBinding {
      // Emit AIR for the initial value.
      try visit(value)

      // Emit AIR for the initial binding.
      builder.build(
        assignment: op,
        source: stack.pop()!,
        target: reference,
        debugInfo: node.debugInfo)
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
      // Higher-order functions are defunctionalized, and represented as partial applications to
      // deal with captured references. Therefore the declaration's environment has to be saved
      // so that the captured references can be injected into the partial application later on.
      // Notice that for all captures are assumed by alias. Other strategies could be considered,
      // and would require assigment instructions to be emitted here.

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

    // Emit AIR for the loop's prologue.
    builder.buildJump(label: test.label)
    builder.currentBlock = test
    try visit(node.condition)
    builder.buildBranch(condition: stack.pop()!, thenLabel: cont.label, elseLabel: post.label)

    // Emit AIR for the loop's body.
    builder.currentBlock = cont
    try visit(node.body)
    builder.buildJump(label: test.label)

    builder.currentBlock = post
  }

  func visit(_ node: BindingStmt) throws {
    // Emit AIR for the operator's operands.
    try visit(node.lvalue)
    let lvalue = stack.pop() as! AIRRegister
    try visit(node.rvalue)
    let rvalue = stack.pop()!

    // Emit AIR for the assignment.
    builder.build(
      assignment: node.op,
      source: rvalue,
      target: lvalue,
      debugInfo: node.debugInfo)
  }

  func visit(_ node: ReturnStmt) throws {
    guard let currentFn = builder.currentBlock?.function
      else { fatalError("not in a function") }

    if let (op, value) = node.binding {
      try visit(value)
      builder.build(
        assignment: op,
        source: stack.pop()!,
        target: returnRegister!,
        debugInfo: node.debugInfo)
    }

    builder.buildJump(label: currentFn.blocks.values.last!.label)
  }

  func visit(_ node: NullRef) {
    stack.push(AIRNull(
      type: typeEmitter.emitType(of: node.type!),
      debugInfo: node.debugInfo))
  }

  func visit(_ node: IfExpr) throws {
    guard let currentFn = builder.currentBlock?.function
      else { fatalError("not in a function") }

    let then = currentFn.insertBlock(after: builder.currentBlock!, label: "then")
    let else_ = currentFn.insertBlock(after: then, label: "else")
    let post = currentFn.insertBlock(after: else_, label: "post")

    // Emit AIR for the conditional's prologue.
    try visit(node.condition)
    builder.buildBranch(condition: stack.pop()!, thenLabel: then.label, elseLabel: else_.label)

    // Emit AIR for the then block.
    builder.currentBlock = then
    try visit(node.thenBlock)
    builder.buildJump(label: post.label)

    // Emit AIR for the else block.
    builder.currentBlock = else_
    if let elseBlock = node.elseBlock {
      try visit(elseBlock)
    }
    builder.buildJump(label: post.label)

    builder.currentBlock = post
  }

  func visit(_ node: CastExpr) throws {
    try visit(node.operand)
    let castTy = typeEmitter.emitType(of: node.type!)
    let unsafeCast = builder.buildUnsafeCast(
      source: stack.pop()!,
      as: castTy,
      debugInfo: node.debugInfo)
    stack.push(unsafeCast)
  }

  func visit(_ node: BinExpr) throws {
    try visit(node.right)
    try visit(node.left)

    let debugInfo: DebugInfo = node.debugInfo
    let register: AIRValue
    switch node.op {
    case .refeq:
      register = builder.buildRefEq(lhs: stack.pop()!, rhs: stack.pop()!, debugInfo: debugInfo)
    case .refne:
      register = builder.buildRefNe(lhs: stack.pop()!, rhs: stack.pop()!, debugInfo: debugInfo)
    default:
      fatalError("unexpected binary operator '\(node.op): \(node.type!)'")
    }

    stack.push(register)
  }

  func visit(_ node: CallExpr) throws {
    var callee: AIRValue?
    var arguments: [AIRValue] = []

    // Emit AIR for the callee.

    if let select = node.callee as? SelectExpr {
      let symbol = select.ownee.symbol!
      if symbol.isMethod && !symbol.isStatic {
        // If the expression is a call to a non-static method, then the latter has to be uncurried
        // and supplied with a reference to the select's owner as its first argument.
        callee = try getAIRMethod(select: select)

        // Emit the `self` argument.
        try visit(select.owner!)
        let argument = stack.pop()!
        if argument is AIRConstant {
          // If `self` is an AIR constant (e.g. a literal number), we supply it directly to the
          // argument list rather creating a parameter assignment.
          arguments.append(argument)
        } else {
          // Create the parameter aliasing assignment for `self`.
          let self_ = builder.buildMakeRef(
            type: typeEmitter.emitType(of: select.owner!.type!),
            debugInfo: select.owner?.debugInfo)
          builder.buildBind(source: argument, target: self_, debugInfo: node.debugInfo)
          arguments.append(self_)
        }
      }
    }

    // Optimization opportunity:
    // If the callee is an identifier referring to an first-order function name, we could avoid the
    // aliasing assignment and refer to the function directly.

    if callee == nil {
      let calleeRegister = builder.buildMakeRef(type: typeEmitter.emitType(of: node.callee.type!))
      try visit(node.callee)
      builder.buildBind(source: stack.pop()!, target: calleeRegister)
      callee = calleeRegister
    }

    // Emit AIR for the arguments.
    try arguments.append(contentsOf: node.arguments.map { (callArgument) -> MakeRefInst in
      // Emit AIR for the argument's reference.
      let argument = builder.buildMakeRef(
        type: typeEmitter.emitType(of: callArgument.type!),
        debugInfo: callArgument.debugInfo)

      // Emit AIR for the argument's value.
      try visit(callArgument.value)
      builder.build(
        assignment:
        callArgument.bindingOp,
        source: stack.pop()!,
        target: argument,
        debugInfo: callArgument.debugInfo)

      return argument
    })

    // Emit AIR for the callee's application.
    let apply = builder.buildApply(
      callee: callee!,
      arguments: arguments,
      type: typeEmitter.emitType(of: node.type!),
      debugInfo: node.debugInfo)
    stack.push(apply)
  }

  func visit(_ node: SelectExpr) throws {
    guard let owner = node.owner
      else { fatalError("Support for implicit not implemented") }
    try visit(owner)

    // FIXME: What about static methods?
    if node.ownee.symbol!.isMethod {
      let airMethod = try getAIRMethod(select: node)
      let partialApplication = builder.buildPartialApply(
        function: airMethod,
        arguments: [stack.pop()!],
        type: typeEmitter.emitType(of: node.type!),
        debugInfo: node.debugInfo)
      stack.push(partialApplication)
      return
    }

    // FIXME: Distinguish between stored and computed properties.

    // If the ownee isn't a method, but the owner's a nominal type, then the expression should
    // "extract" a field from the owner.
    guard let airTy = typeEmitter.emitType(of: owner.type!) as? AIRStructType
      else { fatalError("\(node.ownee.name) is not a stored property of \(owner.type!)") }
    guard let index = airTy.members.firstIndex(where: { $0.key == node.ownee.name })
      else { fatalError("\(node.ownee.name) is not a stored property of \(owner.type!)") }

    let extract = builder.buildExtract(
      from: stack.pop() as! AIRRegister,
      index: index,
      type: typeEmitter.emitType(of: node.type!),
      debugInfo: node.debugInfo)
    stack.push(extract)
  }

  func visit(_ node: Ident) throws {
    // Look for the node's symbol in the accessible scopes.
    if let value = locals[node.symbol!] {
      stack.push(value)
      return
    }

    // If the identifier's symbol isn't declared yet, it either refers to a function or a type
    // constructor (an `undefined symbol` error would have raised during semantic analysis).
    guard let aznTy = (node.type as? FunctionType)
      else { fatalError() }
    let airTy = typeEmitter.emitType(of: aznTy)

    let decl = builder.context.declarations[node.symbol!] as! FunDecl
    requestedImpl.append((decl, aznTy))

    let functionName = decl.getAIRName(specializedWithType: aznTy)
    if let env = thinkFunctionEnvironment[node.symbol!] {
      // If the identifier refers to the name of a thick function, we've to create a closure. As
      // thick functions aren't hoisted, we can assume to environment to have already been set.
      let additional = env.keys.map { typeEmitter.emitType(of: $0.type!) }
      let fnTy = typeEmitter.emitType(from: additional + airTy.domain, to: airTy.codomain)
      let fn = builder.unit.getFunction(name: functionName, type: fnTy)
      let val = builder.buildPartialApply(
        function: fn,
        arguments: Array(env.values),
        type: fnTy,
        debugInfo: node.debugInfo)
      stack.push(val)
    } else {
      // If the identifier refers to the name of a thin function, then we just need to use the
      // corresponding AIR function value.
      let fn = builder.unit.getFunction(name: functionName, type: airTy)
      stack.push(fn)
    }
  }

  func visit(_ node: Literal<Bool>) {
    stack.push(AIRConstant(value: node.value, debugInfo: node.debugInfo))
  }

  func visit(_ node: Literal<Int>) {
    stack.push(AIRConstant(value: node.value, debugInfo: node.debugInfo))
  }

  func visit(_ node: Literal<Double>) {
    stack.push(AIRConstant(value: node.value, debugInfo: node.debugInfo))
  }

  func visit(_ node: Literal<String>) {
    stack.push(AIRConstant(value: node.value, debugInfo: node.debugInfo))
  }

  /// Emit the method type corresponding to a select expression.
  ///
  /// Non-static methods actually have types of the form `(_: Self) -> MethodType` in Anzen. Hence,
  /// They should be uncurried in AIR to accept `self` as their first parameter.
  private func getAIRMethod(select: SelectExpr) throws -> AIRFunction {
    // Emit the type of the uncurried method.
    let calleeAIRType = typeEmitter.emitType(of: select.ownee.type!) as! AIRFunctionType
    let methodAIRType = typeEmitter.emitType(
      from: [typeEmitter.emitType(of: select.owner!.type!)] + calleeAIRType.domain,
      to: calleeAIRType.codomain)

    // Compute the specialized type of the Anzen method (i.e. the curried version of the method's
    // type) to feed the name mangler and register the implementation request.
    let methodAZNType = builder.context.getFunctionType(
      from: [Parameter(label: nil, type: select.owner!.type!)],
      to: select.ownee.type!)

    let decl = builder.context.declarations[select.ownee.symbol!] as! FunDecl
    requestedImpl.append((decl, methodAZNType))

    let functionName = decl.getAIRName(specializedWithType: methodAZNType)
    return builder.unit.getFunction(name: functionName, type: methodAIRType)
  }

}
