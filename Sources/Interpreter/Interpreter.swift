import AnzenIR
import SystemKit
import Utils

/// An interpreter for AIR code.
public class Interpreter {

  /// The standard output of the interpreter.
  public var stdout: TextOutputStream

  /// The standard error of the interpreter.
  public var stderr: TextOutputStream

  /// The instruction pointer.
  private var instructionPointer: InstructionPointer?

  /// The stack frames.
  private var frames: Stack<Frame> = []

  public init(stdout: TextOutputStream = System.out, stderr: TextOutputStream = System.err) {
    self.stdout = stdout
    self.stderr = stderr
  }

  /// Invokes the main function of an AIR unit.
  ///
  /// - Note:
  ///   The interpreter operates under the assumption that the AIR unit it is given is well-formed,
  ///   and will unrecoverably fail otherwise. Other runtime errors (e.g. memory errors) trigger
  ///   exceptions that can be caught to produce nicer error reports.
  public func invoke(function: AIRFunction) throws {
    instructionPointer = InstructionPointer(atEntryOf: function)
    frames.push(Frame())

    while let instruction = instructionPointer?.next() {
      switch instruction {
      case let inst as AllocInst        : try execute(inst)
      case let inst as MakeRefInst      : try execute(inst)
      case let inst as ExtractInst      : try execute(inst)
      case let inst as CopyInst         : try execute(inst)
      case let inst as MoveInst         : try execute(inst)
      case let inst as BindInst         : try execute(inst)
      case let inst as UnsafeCastInst   : try execute(inst)
      case let inst as ApplyInst        : try execute(inst)
      case let inst as PartialApplyInst : try execute(inst)
      case let inst as DropInst         : try execute(inst)
      case let inst as ReturnInst       : try execute(inst)
      case let inst as BranchInst       : try execute(inst)
      case let inst as JumpInst         : try execute(inst)
      default: throw RuntimeError("unexpected instruction '\(instruction.instDescription)'")
      }
    }
  }

  private func execute(_ inst: AllocInst) throws {
    switch inst.type {
    case let type as AIRStructType:
      frames.top![inst.id] = Reference(
        to: ValuePointer(to: StructInstance(type: type)),
        type: type)
    default:
      throw RuntimeError("no allocator for type '\(inst.type)'")
    }
  }

  private func execute(_ inst: MakeRefInst) throws {
    frames.top![inst.id] = Reference(type: inst.type)
  }

  private func execute(_ inst: ExtractInst) throws {
    // Dereference the struct instance.
    guard let container = try valueContainer(of: inst.source)
      else { throw RuntimeError("access to uninitialized memory") }
    guard let instance = container as? StructInstance
      else { throw RuntimeError("'\(container)' is not a struct instance") }

    // Extract the requested field.
    guard instance.payload.count > inst.index
      else { throw RuntimeError("struct field index is out of bound") }
    frames.top![inst.id] = instance.payload[inst.index]
  }

  private func execute(_ inst: CopyInst) throws {
    guard let targetReference = frames.top![inst.target.id]
      else { throw RuntimeError("invalid or uninitialized register '\(inst.target.id)'") }

    guard let sourceContainer = try valueContainer(of: inst.source)
      else { throw RuntimeError("access to uninitialized memory") }

    if let valuePointer = targetReference.pointer {
      valuePointer.pointee = sourceContainer.copy()
    } else {
      targetReference.pointer = ValuePointer(to: sourceContainer.copy())
    }
  }

  private func execute(_ inst: MoveInst) throws {
    guard let targetReference = frames.top![inst.target.id]
      else { throw RuntimeError("invalid or uninitialized register '\(inst.target.id)'") }

    guard let sourceContainer = try valueContainer(of: inst.source)
      else { throw RuntimeError("access to uninitialized memory") }

    if let valuePointer = targetReference.pointer {
      valuePointer.pointee = sourceContainer
    } else {
      targetReference.pointer = ValuePointer(to: sourceContainer)
    }
  }

  private func execute(_ inst: BindInst) throws {
    guard let targetReference = frames.top![inst.target.id]
      else { throw RuntimeError("invalid or uninitialized register '\(inst.target.id)'") }

    switch inst.source {
    case let fun as AIRFunction:
      targetReference.pointer = ValuePointer(to: FunctionValue(function: fun))
    case let reg as AIRRegister:
      targetReference.pointer = frames.top![reg.id]?.pointer
    case is AIRNull:
      targetReference.pointer = nil
    default:
      throw RuntimeError("invalid r-value for bind '\(inst.source)'")
    }
  }

  private func execute(_ inst: UnsafeCastInst) throws {
    // Retrieve the operand's pointer.
    let valuePointer: ValuePointer
    switch inst.operand {
    case let reg as AIRRegister:
      guard let sourceReference = frames.top![reg.id]
        else { throw RuntimeError("invalid or uninitialized register '\(reg.id)'") }
      guard sourceReference.pointer != nil
        else { throw RuntimeError("access to uninitialized memory") }
      valuePointer = sourceReference.pointer!

    default:
      guard let container = try valueContainer(of: inst.operand)
        else { throw RuntimeError("access to uninitialized memory") }
      valuePointer = ValuePointer(to: container)
    }

    // NOTE: Just as C++'s reinterpret_cast, unsafe_cast should actually be a noop. We may however
    // implement some assertion checks in the future.
    frames.top![inst.id] = Reference(to: valuePointer, type: inst.type)
  }

  private func execute(_ inst: ApplyInst) throws {
    // Retrieve the function to be called, and all its arguments.
    guard let container = try valueContainer(of: inst.callee)
      else { throw RuntimeError("access to uninitialized memory") }
    guard let calleeContainer = container as? FunctionValue
      else { throw RuntimeError("'\(container)' is not a function") }

    let function = calleeContainer.function
    let arguments = calleeContainer.closure + inst.arguments

    // Handle built-in funtions.
    if function.name.starts(with: "__") {
      frames.top![inst.id] = try applyBuiltin(name: function.name, arguments: arguments)
      return
    }

    // Prepare the next stack frame. Notice the offset, so as to reserve %0 for `self`.
    var nextFrame = Frame(returnInstructionPointer: instructionPointer, returnID: inst.id)
    for (i, argument) in arguments.enumerated() {
      switch argument {
      case let cst as AIRConstant:
        // Create a new reference, with ownership.
        let value = PrimitiveValue(cst.value as! PrimitiveType)
        nextFrame[i + 1] = Reference(to: ValuePointer(to: value), type: argument.type)

      case let fun as AIRFunction:
        // Create a new reference, without ownership.
        let value = FunctionValue(function: fun)
        nextFrame[i + 1] = Reference(to: ValuePointer(to: value), type: argument.type)

      case let reg as AIRRegister:
        // Take the reference, as is.
        nextFrame[i + 1] = frames.top![reg.id]

      default:
        unreachable()
      }
    }
    frames.push(nextFrame)

    // Jump into the function.
    instructionPointer = InstructionPointer(atEntryOf: function)
  }

  private func execute(_ inst: PartialApplyInst) throws {
    let value = FunctionValue(function: inst.function, closure: inst.arguments)
    frames.top![inst.id] = Reference(to: ValuePointer(to: value), type: inst.type)
  }

  private func execute(_ inst: DropInst) throws {
    frames.top![inst.value.id] = nil
    // FIXME: Call destructors.
  }

  private func execute(_ inst: ReturnInst) throws {
    // Assign the return value (if any) onto the return register.
    if let returnValue = inst.value {
      if frames.count > 1 {
        guard let container = try valueContainer(of: returnValue)
          else { throw RuntimeError("access to uninitialized memory") }
        frames[frames.count - 2][frames.top!.returnID!] = Reference(
          to: ValuePointer(to: container),
          type: returnValue.type)
      }
    }

    // Pop the current frame.
    instructionPointer = frames.top!.returnInstructionPointer
    frames.pop()
  }

  private func execute(_ branch: BranchInst) throws {
    guard let container = try valueContainer(of: branch.condition)
      else { throw RuntimeError("access to uninitialized memory") }
    guard let condition = (container as? PrimitiveValue)?.value as? Bool
      else { throw RuntimeError("'\(container)' is not a boolean value") }

    instructionPointer = condition
      ? InstructionPointer(in: instructionPointer!.function, atBeginningOf: branch.thenLabel)
      : InstructionPointer(in: instructionPointer!.function, atBeginningOf: branch.elseLabel)
  }

  private func execute(_ jump: JumpInst) throws {
    instructionPointer = InstructionPointer(
      in: instructionPointer!.function,
      atBeginningOf: jump.label)
  }

  private func valueContainer(of airValue: AIRValue) throws -> ValueContainer? {
    switch airValue {
    case let cst as AIRConstant:
      return PrimitiveValue(cst.value as! PrimitiveType)

    case let fun as AIRFunction:
      return FunctionValue(function: fun)

    case let reg as AIRRegister:
      guard let reference = frames.top![reg.id]
        else { throw RuntimeError("invalid or uninitialized register '\(reg.id)'") }
      return reference.pointer?.pointee

    default:
      unreachable()
    }
  }

  // MARK: Built-in functions

  private func applyBuiltin(name: String, arguments: [AIRValue]) throws -> Reference? {
    guard let function = builtinFunctions[name]
      else { fatalError("unimplemented built-in function '\(name)'") }

    let argumentContainers = try arguments.map(valueContainer)
    return try function(argumentContainers)
  }

  private typealias BuiltinFunction = ([ValueContainer?]) throws -> Reference?

  private lazy var builtinFunctions: [String: BuiltinFunction] = {
    var result: [String: BuiltinFunction] = [:]

    // Reference identity checks.
    result["__peq"] = { (arguments: [ValueContainer?]) in
      let res = PrimitiveValue(arguments[0] === arguments[1])
      return Reference(to: ValuePointer(to: res), type: res.type)
    }
    result["__pne"] = { (arguments: [ValueContainer?]) in
      let res = PrimitiveValue(arguments[0] !== arguments[1])
      return Reference(to: ValuePointer(to: res), type: res.type)
    }

    // print
    result["__print"] = { (arguments: [ValueContainer?]) in
      if let container = arguments[0] {
        self.stdout.write("\(container)\n")
      } else {
        self.stdout.write("null\n")
      }
      return nil
    }

    // Int
    result["__iadd"] = { primitiveBinaryFunction($0, with: (+)  as (Int, Int) -> Int) }
    result["__isub"] = { primitiveBinaryFunction($0, with: (-)  as (Int, Int) -> Int) }
    result["__imul"] = { primitiveBinaryFunction($0, with: (*)  as (Int, Int) -> Int) }
    result["__idiv"] = { primitiveBinaryFunction($0, with: (/)  as (Int, Int) -> Int) }
    result["__ilt"]  = { primitiveBinaryFunction($0, with: (<)  as (Int, Int) -> Bool) }
    result["__ile"]  = { primitiveBinaryFunction($0, with: (<=) as (Int, Int) -> Bool) }
    result["__ieq"]  = { primitiveBinaryFunction($0, with: (==) as (Int, Int) -> Bool) }
    result["__ine"]  = { primitiveBinaryFunction($0, with: (!=) as (Int, Int) -> Bool) }
    result["__ige"]  = { primitiveBinaryFunction($0, with: (>=) as (Int, Int) -> Bool) }
    result["__igt"]  = { primitiveBinaryFunction($0, with: (>)  as (Int, Int) -> Bool) }

    // Float
    result["__fadd"] = { primitiveBinaryFunction($0, with: (+)  as (Double, Double) -> Double) }
    result["__fsub"] = { primitiveBinaryFunction($0, with: (-)  as (Double, Double) -> Double) }
    result["__fmul"] = { primitiveBinaryFunction($0, with: (*)  as (Double, Double) -> Double) }
    result["__fdiv"] = { primitiveBinaryFunction($0, with: (/)  as (Double, Double) -> Double) }
    result["__flt"]  = { primitiveBinaryFunction($0, with: (<)  as (Double, Double) -> Bool) }
    result["__fle"]  = { primitiveBinaryFunction($0, with: (<=) as (Double, Double) -> Bool) }
    result["__feq"]  = { primitiveBinaryFunction($0, with: (==) as (Double, Double) -> Bool) }
    result["__fne"]  = { primitiveBinaryFunction($0, with: (!=) as (Double, Double) -> Bool) }
    result["__fge"]  = { primitiveBinaryFunction($0, with: (>=) as (Double, Double) -> Bool) }
    result["__fgt"]  = { primitiveBinaryFunction($0, with: (>)  as (Double, Double) -> Bool) }

    return result
  }()

}

private func primitiveBinaryFunction<T, U>(
  _ arguments: [ValueContainer?], with fn: (T, T) -> U) -> Reference?
  where U: PrimitiveType
{
  guard let a = (arguments[0] as? PrimitiveValue)?.value as? T
    else { return nil }
  guard let b = (arguments[1] as? PrimitiveValue)?.value as? T
    else { return nil }

  let res = PrimitiveValue(fn(a, b))
  return Reference(to: ValuePointer(to: res), type: res.type)
}
