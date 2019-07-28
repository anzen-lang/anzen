import AST

/// A driver for a module's AIR code emitting.
public class AIREmissionDriver {

  private var requestedImpl: [(FunDecl, FunctionType)] = []
  private var processedImpl: Set<String> = []

  public init() {}

  public func emitMainUnit(_ module: ModuleDecl, context: ASTContext) -> AIRUnit {
    let unit = AIRUnit(name: module.id?.qualifiedName ?? "__air_unit")
    let builder = AIRBuilder(unit: unit, context: context)

    // Emit the main function's prologue.
    let mainFnType = unit.getFunctionType(from: [], to: .nothing)
    let mainFn = builder.unit.getFunction(name: "main", type: mainFnType)
    mainFn.appendBlock(label: "entry")
    builder.currentBlock = mainFn.appendBlock(label: "exit")
    builder.buildReturn()

    // Emit the main function's body.
    emitFunctionBody(
      builder: builder,
      function: mainFn,
      locals: [:],
      returnRegister: nil,
      body: module.statements,
      typeEmitter: TypeEmitter(builder: builder, typeBindings: [:]))

    // Emit the implementation requests.
    emitImplementationRequests(builder: builder)

    return unit
  }

  private func emitFunctionPrologue(
    builder: AIRBuilder,
    name: String,
    declaration: FunDecl,
    type: FunctionType,
    typeEmitter: TypeEmitter) -> FunctionPrologue
  {
    var fnType = typeEmitter.emitType(of: type)

    if declaration.kind == .method || declaration.kind == .destructor {
      // Methods and destructors are lowered into static functions that take the self symbol and
      // return the "actual" method as a closure.
      let symbols = declaration.innerScope!.symbols["self"]!
      assert(symbols.count == 1)
      let methTy = fnType.codomain as! AIRFunctionType
      fnType = builder.unit.getFunctionType(
        from: fnType.domain + methTy.domain,
        to: methTy.codomain)
    } else if !declaration.captures.isEmpty {
      // If the function captures symbols, we need to emit a context-free version of the it, which
      // gets the captured values as parameters. This boils down to extending the domain.
      let additional = declaration.captures.map { typeEmitter.emitType(of: $0.type!) }
      fnType = builder.unit.getFunctionType(from: additional + fnType.domain, to: fnType.codomain)
    }

    // Retrieve the function object.
    let function = builder.unit.getFunction(name: name, type: fnType)
    function.debugInfo = declaration.debugInfo
    function.debugInfo![.anzenType] = type

    assert(function.blocks.isEmpty)
    builder.currentBlock = function.appendBlock(label: "entry")

    // Create the function's locals.
    var locals: [Symbol: AIRValue] = [:]

    // Handle self for constructors, desctructors and methods.
    if declaration.kind != .regular {
      let selfSymbol = declaration.innerScope!.symbols["self"]![0]
      let debugInfo: DebugInfo = [
        .range: declaration.range,
        .anzenType: selfSymbol.type!,
        .name: "self"]

      locals[selfSymbol] = declaration.kind == .constructor
        ? builder.buildAlloc(type: fnType.codomain, withID: 0, debugInfo: debugInfo)
        : AIRParameter(
          type: fnType.domain[0],
          id: builder.currentBlock!.nextRegisterID(),
          debugInfo: debugInfo)
    }

    // Create the function parameters captured by closure.
    for sym in declaration.captures {
      let paramref = AIRParameter(
        type: typeEmitter.emitType(of: sym.type!),
        id: builder.currentBlock!.nextRegisterID(),
        debugInfo: [.anzenType: sym.type!, .name: sym.name])
      locals[sym] = paramref
    }

    // Create the function parameters.
    for (paramDecl, paramSign) in zip(declaration.parameters, type.domain) {
      let paramref = AIRParameter(
        type: typeEmitter.emitType(of: paramSign.type),
        id: builder.currentBlock!.nextRegisterID(),
        debugInfo: paramDecl.debugInfo)
      locals[paramDecl.symbol!] = paramref
    }

    // Create the return register.
    let returnRegister: AIRRegister?
    if declaration.kind == .constructor {
      let selfSymbol = declaration.innerScope!.symbols["self"]![0]
      returnRegister = locals[selfSymbol] as? AIRRegister
    } else if type.codomain != NothingType.get {
      returnRegister = builder.buildMakeRef(type: fnType.codomain, withID: 0)
    } else {
      returnRegister = nil
    }

    // Emit the function return.
    builder.currentBlock = function.appendBlock(label: "exit")
    if returnRegister != nil {
      builder.buildReturn(value: returnRegister!)
    } else {
      builder.buildReturn()
    }

    return FunctionPrologue(function: function, locals: locals, returnRegister: returnRegister)
  }

  // swiftlint:disable function_parameter_count
  private func emitFunctionBody(
    builder: AIRBuilder,
    function: AIRFunction,
    locals: [Symbol: AIRValue],
    returnRegister: AIRRegister?,
    body: [Node],
    typeEmitter: TypeEmitter)
  {
    // Set the builder's cursor.
    builder.currentBlock = function.blocks.first?.value

    // Emit the function's body.
    let emitter = AIREmitter(
      builder: builder,
      locals: locals,
      returnRegister: returnRegister,
      typeEmitter: typeEmitter)
    try! emitter.visit(body)

    // Make sure the last instruction is a jump to the exit block.
    if !(builder.currentBlock!.instructions.last is JumpInst) {
      builder.buildJump(label: function.blocks.last!.value.label)
    }

    // Save the implementation requests.
    requestedImpl.append(contentsOf: emitter.requestedImpl)
  }
  // swiftlint:enable function_parameter_count

  private func emitImplementationRequests(builder: AIRBuilder) {
    while let (decl, type) = requestedImpl.popLast() {
      let functionName = decl.getAIRName(specializedWithType: type)
      guard !processedImpl.contains(functionName)
        else { continue }
      processedImpl.insert(functionName)

      guard let functionBody = decl.body
        else { continue }

      var typeBindings: [PlaceholderType: TypeBase] = [:]
      guard specializes(lhs: type, rhs: decl.type!, in: builder.context, bindings: &typeBindings)
        else { fatalError("type mismatch") }

      let typeEmitter = TypeEmitter(builder: builder, typeBindings: typeBindings)

      let prologue = emitFunctionPrologue(
        builder: builder,
        name: functionName,
        declaration: decl,
        type: type,
        typeEmitter: typeEmitter)

      emitFunctionBody(
        builder: builder,
        function: prologue.function,
        locals: prologue.locals,
        returnRegister: prologue.returnRegister,
        body: functionBody.statements,
        typeEmitter: typeEmitter)
    }
  }

}

private struct FunctionPrologue {

  let function: AIRFunction
  let locals: [Symbol: AIRValue]
  let returnRegister: AIRRegister?

}
