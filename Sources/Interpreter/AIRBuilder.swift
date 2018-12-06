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
  public func buildMakeRef(type: AIRType) -> MakeRefInst {
    let inst = MakeRefInst(type: type, name: currentBlock!.nextRegisterName())
    currentBlock!.instructions.append(inst)
    return inst
  }

  public func buildAlloc(type: AIRType) -> AllocInst {
    let inst = AllocInst(type: type, name: currentBlock!.nextRegisterName())
    currentBlock!.instructions.append(inst)
    return inst
  }

  public func buildApply(callee: AIRValue, arguments: [AIRValue], type: AIRType) -> ApplyInst {
    let inst = ApplyInst(
      callee: callee,
      arguments: arguments,
      type: type,
      name: currentBlock!.nextRegisterName())
    currentBlock!.instructions.append(inst)
    return inst
  }

  public func buildPartialApply(function: AIRFunction, arguments: [AIRValue], type: AIRType)
    -> PartialApplyInst
  {
    let inst = PartialApplyInst(
      function: function,
      arguments: arguments,
      type: type,
      name: currentBlock!.nextRegisterName())
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
  public func buildCopy(source: AIRValue, target: MakeRefInst) -> CopyInst {
    let inst = CopyInst(source: source, target: target)
    currentBlock!.instructions.append(inst)
    return inst
  }

  @discardableResult
  public func buildMove(source: AIRValue, target: MakeRefInst) -> MoveInst {
    let inst = MoveInst(source: source, target: target)
    currentBlock!.instructions.append(inst)
    return inst
  }

  @discardableResult
  public func buildBind(source: AIRValue, target: MakeRefInst) -> BindInst {
    let inst = BindInst(source: source, target: target)
    currentBlock!.instructions.append(inst)
    return inst
  }

  @discardableResult
  public func build(
    assignment: BindingOperator,
    source: AIRValue,
    target: MakeRefInst) -> AIRInstruction
  {
    switch assignment {
    case .copy: return buildCopy(source: source, target: target)
    case .move: return buildMove(source: source, target: target)
    case .ref : return buildBind(source: source, target: target)
    }
  }

  @discardableResult
  public func buildDrop(value: MakeRefInst) -> DropInst {
    let inst = DropInst(value: value)
    currentBlock!.instructions.append(inst)
    return inst
  }

  @discardableResult
  public func buildBranch(condition: AIRValue, thenLabel: String, elseLabel: String) -> BranchInst {
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
