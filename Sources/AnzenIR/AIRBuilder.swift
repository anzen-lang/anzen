import AST

public class AIRBuilder {

  public init(unit: AIRUnit, context: ASTContext) {
    self.unit = unit
    self.context = context
  }

  /// The AIR unit being edited.
  public let unit: AIRUnit
  /// The AST context of the unit.
  public let context: ASTContext
  /// The current instruction block.
  public var currentBlock: InstructionBlock?

  /// Creates a new reference in the current instruction block.
  public func buildMakeRef(
    type: AIRType,
    withID id: Int? = nil,
    debugInfo: DebugInfo? = nil) -> MakeRefInst
  {
    let registerID = id ?? currentBlock!.nextRegisterID()
    let inst = MakeRefInst(type: type, id: registerID, debugInfo: debugInfo)
    currentBlock!.instructions.append(inst)
    return inst
  }

  public func buildAlloc(
    type: AIRType,
    withID id: Int? = nil,
    debugInfo: DebugInfo? = nil) -> AllocInst
  {
    let registerID = id ?? currentBlock!.nextRegisterID()
    let inst = AllocInst(type: type, id: registerID, debugInfo: debugInfo)
    currentBlock!.instructions.append(inst)
    return inst
  }

  public func buildUnsafeCast(
    source: AIRValue,
    as castType: AIRType,
    withID id: Int? = nil,
    debugInfo: DebugInfo? = nil) -> UnsafeCastInst
  {
    let registerID = id ?? currentBlock!.nextRegisterID()
    let inst = UnsafeCastInst(
      operand: source,
      type: castType,
      id: registerID,
      debugInfo: debugInfo)
    currentBlock!.instructions.append(inst)
    return inst
  }

  public func buildExtract(
    from source: AIRRegister,
    index: Int,
    type: AIRType,
    withID id: Int? = nil,
    debugInfo: DebugInfo? = nil) -> ExtractInst
  {
    let registerID = id ?? currentBlock!.nextRegisterID()
    let inst = ExtractInst(
      source: source,
      index: index,
      type: type,
      id: registerID,
      debugInfo: debugInfo)
    currentBlock!.instructions.append(inst)
    return inst
  }

  public func buildRefEq(
    lhs: AIRValue,
    rhs: AIRValue,
    withID id: Int? = nil,
    debugInfo: DebugInfo? = nil) -> RefEqInst
  {
    let registerID = id ?? currentBlock!.nextRegisterID()
    let inst = RefEqInst(lhs: lhs, rhs: rhs, id: registerID, debugInfo: debugInfo)
    currentBlock!.instructions.append(inst)
    return inst
  }

  public func buildRefNe(
    lhs: AIRValue,
    rhs: AIRValue,
    withID id: Int? = nil,
    debugInfo: DebugInfo? = nil) -> RefNeInst
  {
    let registerID = id ?? currentBlock!.nextRegisterID()
    let inst = RefNeInst(lhs: lhs, rhs: rhs, id: registerID, debugInfo: debugInfo)
    currentBlock!.instructions.append(inst)
    return inst
  }

  public func buildApply(
    callee: AIRValue,
    arguments: [AIRValue],
    type: AIRType,
    withID id: Int? = nil,
    debugInfo: DebugInfo? = nil) -> ApplyInst
  {
    let registerID = id ?? currentBlock!.nextRegisterID()
    let inst = ApplyInst(
      callee: callee,
      arguments: arguments,
      type: type,
      id: registerID,
      debugInfo: debugInfo)
    currentBlock!.instructions.append(inst)
    return inst
  }

  public func buildPartialApply(
    function: AIRFunction,
    arguments: [AIRValue],
    type: AIRType,
    withID id: Int? = nil,
    debugInfo: DebugInfo? = nil) -> PartialApplyInst
  {
    let registerID = id ?? currentBlock!.nextRegisterID()
    let inst = PartialApplyInst(
      function: function,
      arguments: arguments,
      type: type,
      id: registerID,
      debugInfo: debugInfo)
    currentBlock!.instructions.append(inst)
    return inst
  }

  @discardableResult
  public func buildReturn(value: AIRValue? = nil) -> ReturnInst {
    let inst = ReturnInst(value: value)
    currentBlock!.instructions.append(inst)
    return inst
  }

  @discardableResult
  public func buildCopy(source: AIRValue, target: AIRRegister, debugInfo: DebugInfo? = nil)
    -> CopyInst
  {
    let inst = CopyInst(source: source, target: target, debugInfo: debugInfo)
    currentBlock!.instructions.append(inst)
    return inst
  }

  @discardableResult
  public func buildMove(source: AIRValue, target: AIRRegister, debugInfo: DebugInfo? = nil)
    -> MoveInst
  {
    let inst = MoveInst(source: source, target: target, debugInfo: debugInfo)
    currentBlock!.instructions.append(inst)
    return inst
  }

  @discardableResult
  public func buildBind(source: AIRValue, target: AIRRegister, debugInfo: DebugInfo? = nil)
    -> BindInst
  {
    let inst = BindInst(source: source, target: target, debugInfo: debugInfo)
    currentBlock!.instructions.append(inst)
    return inst
  }

  @discardableResult
  public func build(
    assignment: BindingOperator,
    source: AIRValue,
    target: AIRRegister,
    debugInfo: DebugInfo? = nil) -> AIRInstruction
  {
    switch assignment {
    case .copy: return buildCopy(source: source, target: target, debugInfo: debugInfo)
    case .move: return buildMove(source: source, target: target, debugInfo: debugInfo)
    case .ref : return buildBind(source: source, target: target, debugInfo: debugInfo)
    }
  }

  @discardableResult
  public func buildDrop(value: MakeRefInst, debugInfo: DebugInfo? = nil) -> DropInst {
    let inst = DropInst(value: value, debugInfo: debugInfo)
    currentBlock!.instructions.append(inst)
    return inst
  }

  @discardableResult
  public func buildBranch(
    condition: AIRValue,
    thenLabel: String,
    elseLabel: String,
    debugInfo: DebugInfo? = nil) -> BranchInst
  {
    let inst = BranchInst(
      condition: condition,
      thenLabel: thenLabel,
      elseLabel: elseLabel,
      debugInfo: debugInfo)
    currentBlock!.instructions.append(inst)
    return inst
  }

  @discardableResult
  public func buildJump(label: String, debugInfo: DebugInfo? = nil) -> JumpInst {
    let inst = JumpInst(label: label, debugInfo: debugInfo)
    currentBlock!.instructions.append(inst)
    return inst
  }

}
