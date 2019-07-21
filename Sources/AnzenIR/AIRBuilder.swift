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
  public func buildMakeRef(type: AIRType, withID id: Int? = nil) -> MakeRefInst {
    let registerID = id ?? currentBlock!.nextRegisterID()
    let inst = MakeRefInst(type: type, id: registerID)
    currentBlock!.instructions.append(inst)
    return inst
  }

  public func buildAlloc(type: AIRType, withID id: Int? = nil) -> AllocInst {
    let registerID = id ?? currentBlock!.nextRegisterID()
    let inst = AllocInst(type: type, id: registerID)
    currentBlock!.instructions.append(inst)
    return inst
  }

  public func buildUnsafeCast(
    source: AIRValue,
    as castType: AIRType,
    at range: SourceRange?,
    withID id: Int? = nil) -> UnsafeCastInst
  {
    let registerID = id ?? currentBlock!.nextRegisterID()
    let inst = UnsafeCastInst(operand: source, type: castType, id: registerID, range: range)
    currentBlock!.instructions.append(inst)
    return inst
  }

  public func buildExtract(
    from source: AIRValue,
    index: Int,
    type: AIRType,
    at range: SourceRange?,
    withID id: Int? = nil) -> ExtractInst
  {
    let registerID = id ?? currentBlock!.nextRegisterID()
    let inst = ExtractInst(source: source, index: index, type: type, id: registerID, range: range)
    currentBlock!.instructions.append(inst)
    return inst
  }

  public func buildApply(
    callee: AIRValue,
    arguments: [AIRValue],
    type: AIRType,
    at range: SourceRange?,
    withID id: Int? = nil) -> ApplyInst
  {
    let registerID = id ?? currentBlock!.nextRegisterID()
    let inst = ApplyInst(
      callee: callee,
      arguments: arguments,
      type: type,
      id: registerID,
      range: range)
    currentBlock!.instructions.append(inst)
    return inst
  }

  public func buildPartialApply(
    function: AIRFunction,
    arguments: [AIRValue],
    type: AIRType,
    at range: SourceRange?,
    withID id: Int? = nil) -> PartialApplyInst
  {
    let registerID = id ?? currentBlock!.nextRegisterID()
    let inst = PartialApplyInst(
      function: function,
      arguments: arguments,
      type: type,
      id: registerID,
      range: range)
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
  public func buildCopy(source: AIRValue, target: AIRRegister, at range: SourceRange?)
    -> CopyInst
  {
    let inst = CopyInst(source: source, target: target, range: range)
    currentBlock!.instructions.append(inst)
    return inst
  }

  @discardableResult
  public func buildMove(source: AIRValue, target: AIRRegister, at range: SourceRange?)
    -> MoveInst
  {
    let inst = MoveInst(source: source, target: target, range: range)
    currentBlock!.instructions.append(inst)
    return inst
  }

  @discardableResult
  public func buildBind(source: AIRValue, target: AIRRegister, at range: SourceRange?)
    -> BindInst
  {
    let inst = BindInst(source: source, target: target, range: range)
    currentBlock!.instructions.append(inst)
    return inst
  }

  @discardableResult
  public func build(
    assignment: BindingOperator,
    source: AIRValue,
    target: AIRRegister,
    at range: SourceRange?) -> AIRInstruction
  {
    switch assignment {
    case .copy: return buildCopy(source: source, target: target, at: range)
    case .move: return buildMove(source: source, target: target, at: range)
    case .ref : return buildBind(source: source, target: target, at: range)
    }
  }

  @discardableResult
  public func buildDrop(value: MakeRefInst, at range: SourceRange?) -> DropInst {
    let inst = DropInst(value: value, range: range)
    currentBlock!.instructions.append(inst)
    return inst
  }

  @discardableResult
  public func buildBranch(
    condition: AIRValue,
    thenLabel: String,
    elseLabel: String) -> BranchInst
  {
    let inst = BranchInst(condition: condition, thenLabel: thenLabel, elseLabel: elseLabel)
    currentBlock!.instructions.append(inst)
    return inst
  }

  @discardableResult
  public func buildJump(label: String) -> JumpInst {
    let inst = JumpInst(label: label)
    currentBlock!.instructions.append(inst)
    return inst
  }

}
