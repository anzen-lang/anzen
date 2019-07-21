import AST
import Utils

/// An AIR instruction.
public protocol AIRInstruction {

  /// The text description of the instruction.
  var instDescription: String { get }

}

/// A sequence of instructions.
public class InstructionBlock: Sequence {

  /// The label of the block.
  public let label: String
  /// The function in which the block's defined.
  public unowned var function: AIRFunction
  /// The instructions of the block.
  public var instructions: [AIRInstruction] = []

  public init(label: String, function: AIRFunction) {
    self.label = label
    self.function = function
  }

  public func nextRegisterID() -> Int {
    return function.nextRegisterID()
  }

  public func makeIterator() -> Array<AIRInstruction>.Iterator {
    return instructions.makeIterator()
  }

  public var description: String {
    return instructions.map({ $0.instDescription }).joined(separator: "\n")
  }

}

/// An object allocation.
public struct AllocInst: AIRInstruction, AIRRegister {

  /// The type of the allocated object.
  public let type: AIRType
  /// The ID of the register.
  public let id: Int

  public var valueDescription: String {
    return "%\(id)"
  }

  public var instDescription: String {
    return "%\(id) = alloc \(type)"
  }

}

/// A reference allocation.
public struct MakeRefInst: AIRInstruction, AIRRegister {

  /// The type of the allocated reference.
  public let type: AIRType
  /// The ID of the register.
  public let id: Int

  public var valueDescription: String {
    return "%\(id)"
  }

  public var instDescription: String {
    return "%\(id) = make_ref \(type)"
  }

}

/// An unsafe cast.
public struct UnsafeCastInst: AIRInstruction, AIRRegister {

  /// The operand of the case expression.
  public let operand: AIRValue
  /// The type to which the operand shall be casted.
  public let type: AIRType
  /// Thie ID of the register.
  public let id: Int
  /// The range in the Anzen source corresponding to this instruction.
  public let range: SourceRange?

  public var valueDescription: String {
    return "%\(id)"
  }

  public var instDescription: String {
    return "%\(id) = unsafe_cast \(operand.valueDescription) to \(type)"
  }

}

/// Extracts a reference from an aggregate data structure.
///
/// - Note:
///   This intruction only extracts references that are part of the storage of the source (i.e. it
///   doesn't handle computed properties).
public struct ExtractInst: AIRInstruction, AIRRegister {

  /// The instance from which the extraction is performed.
  public let source: AIRRegister
  /// The index of the reference to extract.
  public let index: Int
  /// The type of the extracted member.
  public let type: AIRType
  /// Thie ID of the register.
  public let id: Int
  /// The range in the Anzen source corresponding to this instruction.
  public let range: SourceRange?

  public var valueDescription: String {
    return "%\(id)"
  }

  public var instDescription: String {
    return "%\(id) = extract \(source.valueDescription), \(index)"
  }

}

/// A reference identity check.
public struct RefEqInst: AIRInstruction, AIRRegister {

  /// The left operand.
  public let lhs: AIRValue
  /// The right operand.
  public let rhs: AIRValue
  /// Thie ID of the register.
  public let id: Int
  /// The range in the Anzen source corresponding to this instruction.
  public let range: SourceRange?
  /// The type of the instruction's result.
  public let type: AIRType = .bool

  public var valueDescription: String {
    return "%\(id)"
  }

  public var instDescription: String {
    return "%\(id) = ref_eq \(lhs.valueDescription), \(rhs.valueDescription)"
  }

}

/// A negated reference identity check.
public struct RefNeInst: AIRInstruction, AIRRegister {

  /// The left operand.
  public let lhs: AIRValue
  /// The right operand.
  public let rhs: AIRValue
  /// Thie ID of the register.
  public let id: Int
  /// The range in the Anzen source corresponding to this instruction.
  public let range: SourceRange?
  /// The type of the instruction's result.
  public let type: AIRType = .bool

  public var valueDescription: String {
    return "%\(id)"
  }

  public var instDescription: String {
    return "%\(id) = ref_ne \(lhs.valueDescription), \(rhs.valueDescription)"
  }

}

/// A function application.
public struct ApplyInst: AIRInstruction, AIRRegister {

  /// The callee being applied.
  public let callee: AIRValue
  /// The arguments to which the callee is applied.
  public let arguments: [AIRValue]
  /// The type of the application's result.
  public let type: AIRType
  /// Thie ID of the register.
  public let id: Int
  /// The range in the Anzen source corresponding to this instruction.
  public let range: SourceRange?

  internal init(
    callee: AIRValue,
    arguments: [AIRValue],
    type: AIRType,
    id: Int,
    range: SourceRange?)
  {
    self.callee = callee
    self.arguments = arguments
    self.type = type
    self.id = id
    self.range = range
  }

  public var valueDescription: String {
    return "%\(id)"
  }

  public var instDescription: String {
    let args = arguments
      .map({ $0.valueDescription })
      .joined(separator: ", ")
    return "%\(id) = apply \(callee.valueDescription), \(args)"
  }

}

/// A function's partial application.
///
/// A partial application keeps a reference to another function as well as a partial sequence of
/// arguments. When applied, the backing function is called with the stored arguments first,
/// followed by those that are provided additionally.
public struct PartialApplyInst: AIRInstruction, AIRRegister {

  /// The function being partially applied.
  public let function: AIRFunction
  /// The arguments to which the function is partially applied.
  public let arguments: [AIRValue]
  /// The type of the partial application's result.
  public let type: AIRType
  /// Thie ID of the register.
  public let id: Int
  /// The range in the Anzen source corresponding to this instruction.
  public let range: SourceRange?

  public var valueDescription: String {
    return "%\(id)"
  }

  public var instDescription: String {
    let args = arguments
      .map({ $0.valueDescription })
      .joined(separator: ", ")
    return "%\(id) = partial_apply \(function.valueDescription), \(args)"
  }

}

/// A function return
public struct ReturnInst: AIRInstruction {

  /// The return value.
  public let value: AIRValue?

  public var instDescription: String {
    if let value = value?.valueDescription {
      return "ret \(value)"
    } else {
      return "ret"
    }
  }

}

/// A copy assignment.
public struct CopyInst: AIRInstruction {

  /// The assignmnent's right operand.
  public let source: AIRValue
  /// The assignmnent's left operand.
  public let target: AIRRegister
  /// The range in the Anzen source corresponding to this instruction.
  public let range: SourceRange?

  public var instDescription: String {
    return "copy \(source.valueDescription), \(target.valueDescription)"
  }

}

/// A move assignment.
public struct MoveInst: AIRInstruction {

  /// The assignmnent's right operand.
  public let source: AIRValue
  /// The assignmnent's left operand.
  public let target: AIRRegister
  /// The range in the Anzen source corresponding to this instruction.
  public let range: SourceRange?

  public var instDescription: String {
    return "move \(source.valueDescription), \(target.valueDescription)"
  }

}

/// An aliasing assignment.
public struct BindInst: AIRInstruction {

  /// The assignmnent's right operand.
  public let source: AIRValue
  /// The assignmnent's left operand.
  public let target: AIRRegister
  /// The range in the Anzen source corresponding to this instruction.
  public let range: SourceRange?

  public var instDescription: String {
    return "bind \(source.valueDescription), \(target.valueDescription)"
  }

}

/// A drop instruction.
public struct DropInst: AIRInstruction {

  /// The value being dropped.
  public let value: MakeRefInst
  /// The range in the Anzen source corresponding to this instruction.
  public let range: SourceRange?

  public var instDescription: String {
    return "drop \(value.valueDescription)"
  }

}

/// A conditional jump instruction.
public struct BranchInst: AIRInstruction {

  /// The conditional expression's condition.
  public let condition: AIRValue
  /// The label to which jump if the condition holds.
  public let thenLabel: String
  /// The label to which jump if the condition doesn't hold.
  public let elseLabel: String

  public var instDescription: String {
    return "branch \(condition.valueDescription), \(thenLabel), \(elseLabel)"
  }

}

/// An unconditional jump instruction.
public struct JumpInst: AIRInstruction {

  /// The label to which jump.
  public let label: String

  public var instDescription: String {
    return "jump \(label)"
  }

}
