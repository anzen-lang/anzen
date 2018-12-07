import Utils

public protocol AIRInstruction {

  /// The text description of the instruction.
  var instDescription: String { get }

}

/// This represents a sequence of instructions.
public class InstructionBlock: Sequence {

  public init(label: String, function: AIRFunction) {
    self.label = label
    self.function = function
  }

  /// The label of the block.
  public let label: String
  /// The function in which the block's defined.
  public unowned var function: AIRFunction
  /// The instructions of the block.
  public var instructions: [AIRInstruction] = []

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

/// This represents the allocation of an object.
public struct AllocInst: AIRInstruction, AIRRegister {

  public let type: AIRType
  public let id: Int

  public var valueDescription: String {
    return "%\(id)"
  }

  public var instDescription: String {
    return "%\(id) = alloc \(type)"
  }

}

/// This represents the allocation of a reference (i.e. a pointer), which is provided unintialized.
public struct MakeRefInst: AIRInstruction, AIRRegister {

  public let type: AIRType
  public let id: Int

  public var valueDescription: String {
    return "%\(id)"
  }

  public var instDescription: String {
    return "%\(id) = make_ref \(type)"
  }

}

/// This represents the extraction of a reference from a composite type.
///
/// - Note: This intruction only extracts references that are part of the storage of the source
///   (i.e. it doesn't handle computed properties).
public struct ExtractInst: AIRInstruction, AIRRegister {

  /// The composite type from which the extraction is performed.
  public let source: AIRValue
  /// The index of the reference to extract.
  public let index: Int

  public let type: AIRType
  public let id: Int

  public var valueDescription: String {
    return "%\(id)"
  }

  public var instDescription: String {
    return "%\(id) = extract \(source.valueDescription), \(index)"
  }

}

/// This represents the application of a function.
public struct ApplyInst: AIRInstruction, AIRRegister {

  internal init(callee: AIRValue, arguments: [AIRValue], type: AIRType, id: Int) {
    self.callee = callee
    self.arguments = arguments
    self.type = type
    self.id = id
  }

  public let callee: AIRValue
  public let arguments: [AIRValue]
  public let type: AIRType
  public let id: Int

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

/// This represents the partial application of a function.
///
/// A partial application keeps a reference to another function as well as a partial sequence of
/// arguments. When applied, the backing function is called with the stored arguments first,
/// followed by those that are provided additionally.
public struct PartialApplyInst: AIRInstruction, AIRRegister {

  public let function: AIRFunction
  public let arguments: [AIRValue]
  public let type: AIRType
  public let id: Int

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

/// This represents a function return.
public struct ReturnInst: AIRInstruction {

  public let value: AIRValue?

  public var instDescription: String {
    if let value = value?.valueDescription {
      return "ret \(value)"
    } else {
      return "ret"
    }
  }

}

/// This represents a copy assignment.
public struct CopyInst: AIRInstruction {

  public let source: AIRValue
  public let target: AIRRegister

  public var instDescription: String {
    return "copy \(source.valueDescription), \(target.valueDescription)"
  }

}

/// This represents a move assignment.
public struct MoveInst: AIRInstruction {

  public let source: AIRValue
  public let target: AIRRegister

  public var instDescription: String {
    return "move \(source.valueDescription), \(target.valueDescription)"
  }

}

/// This represents a borrow assignment.
public struct BindInst: AIRInstruction {

  public let source: AIRValue
  public let target: AIRRegister

  public var instDescription: String {
    return "bind \(source.valueDescription), \(target.valueDescription)"
  }

}

/// This represents a drop instruction.
public struct DropInst: AIRInstruction {

  public let value: MakeRefInst

  public var instDescription: String {
    return "drop \(value.valueDescription)"
  }

}

/// This represents a conditional jump instruction.
public struct BranchInst: AIRInstruction {

  public let condition: AIRValue
  public let thenLabel: String
  public let elseLabel: String

  public var instDescription: String {
    return "branch \(condition.valueDescription) \(thenLabel) \(elseLabel)"
  }

}

/// This represents an unconditional jump instruction.
public struct JumpInst: AIRInstruction {

  public let label: String

  public var instDescription: String {
    return "jump \(label)"
  }

}