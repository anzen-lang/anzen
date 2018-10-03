import AST
import Utils

public protocol AIRInstruction {

  /// The text description of the instruction.
  var instDescription: String { get }

}

/// This represents a sequence of instructions.
public class InstructionBlock: Sequence {

  public init(function: AIRFunction) {
    self.function = function
  }

  /// The instructions of the block.
  public var instructions: [AIRInstruction] = []
  /// The function in which the block's defined.
  public unowned var function: AIRFunction
  /// The ID of the next unnamed virtual register.
  public var nextRegisterID = 0

  public func nextName() -> String {
    defer { nextRegisterID += 1 }
    return nextRegisterID.description
  }

  public func makeIterator() -> Array<AIRInstruction>.Iterator {
    return instructions.makeIterator()
  }

  public var description: String {
    return instructions.map({ $0.instDescription }).joined(separator: "\n")
  }

}

/// This represents the allocation of a reference (i.e. a pointer), which is provided unintialized.
public struct AllocInst: AIRInstruction, AIRRegister {

  public let type: TypeBase
  public let name: String

  public var valueDescription: String {
    return "%\(name)"
  }

  public var instDescription: String {
    return "%\(name) = alloc \(type)\n"
  }

}

/// This represents the application of a function.
public struct ApplyInst: AIRInstruction, AIRRegister {

  internal init(callee: AIRValue, arguments: [AIRValue], type: TypeBase, name: String) {
    self.callee = callee
    self.arguments = arguments
    self.type = type
    self.name = name
  }

  public let callee: AIRValue
  public let arguments: [AIRValue]
  public let type: TypeBase
  public let name: String

  public var valueDescription: String {
    return "%\(name)"
  }

  public var instDescription: String {
    let args = arguments
      .map({ $0.valueDescription })
      .joined(separator: ", ")
    return "%\(name) = apply \(callee.valueDescription), \(args)\n"
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
  public let target: AllocInst

  public var instDescription: String {
    return "copy \(source.valueDescription), \(target.valueDescription)"
  }

}

/// This represents a move assignment.
public struct MoveInst: AIRInstruction {

  public let source: AIRValue
  public let target: AllocInst

  public var instDescription: String {
    return "move \(source.valueDescription), \(target.valueDescription)"
  }

}

/// This represents a binding assignment.
public struct BindInst: AIRInstruction {

  public let source: AIRValue
  public let target: AllocInst

  public var instDescription: String {
    return "bind \(source.valueDescription), \(target.valueDescription)"
  }

}

/// This represents a drop instruction.
public struct DropInst: AIRInstruction {

  public let value: AllocInst

  public var instDescription: String {
    return "drop \(value.valueDescription)"
  }

}
