import AnzenIR
import SystemKit
import Utils

/// An interpreter for AIR code.
///
/// - Note: This interpreter operates under the assumption that the AIR units it is given are
///   correct with respect to type checking and borrow checking, and will unrecoverably fail if
///   that's not the case.
public class Interpreter {

  public init(stdout: TextOutputStream = System.out, stderr: TextOutputStream = System.err) {
    self.stdout = stdout
    self.stderr = stderr
  }

  /// The standard output of the interpreter.
  public var stdout: TextOutputStream
  /// The standard error of the interpreter.
  public var stderr: TextOutputStream

  /// The program cursor.
  private var cursor: Cursor?
  /// The stack frames.
  private var frames: Stack<Frame> = []

  public func invoke(function: AIRFunction) throws {
    cursor = Cursor(atEntryOf: function)
    frames.push(Frame())

    while let instruction = cursor?.next() {
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
    let container = try valueContainer(of: inst.source)
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

    let sourceContainer = try valueContainer(of: inst.source).copy()

    if let valuePointer = targetReference.pointer {
      valuePointer.pointee = sourceContainer
    } else {
      targetReference.pointer = ValuePointer(to: sourceContainer)
    }
  }

  private func execute(_ inst: MoveInst) throws {
    guard let targetReference = frames.top![inst.target.id]
      else { throw RuntimeError("invalid or uninitialized register '\(inst.target.id)'") }

    let sourceContainer = try valueContainer(of: inst.source)

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
      valuePointer = ValuePointer(to: try valueContainer(of: inst.operand))
    }

    // NOTE: Just as C++'s reinterpret_cast, unsafe_cast should actually be a noop. We may however
    // implement some assertion checks in the future.
    frames.top![inst.id] = Reference(to: valuePointer, type: inst.type)
  }

  private func execute(_ inst: ApplyInst) throws {
    // Retrieve the function to be called, and all its arguments.
    let container = try valueContainer(of: inst.callee)
    guard let calleeContainer = container as? FunctionValue
      else { throw RuntimeError("'\(container)' is not a function") }

    let function = calleeContainer.function
    let arguments = calleeContainer.closure + inst.arguments

    // Handle built-in funtions.
    if function.name.starts(with: "__builtin") {
      frames.top![inst.id] = try applyBuiltin(name: function.name, arguments: arguments)
      return
    }

    // Prepare the next stack frame. Notice the offset, so as to reserve %0 for `self`.
    var nextFrame = Frame(returnCursor: cursor, returnID: inst.id)
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
    cursor = Cursor(atEntryOf: function)
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
        frames[frames.count - 2][frames.top!.returnID!] = Reference(
          to: ValuePointer(to: try valueContainer(of: returnValue)),
          type: returnValue.type)
      }
    }

    // Pop the current frame.
    cursor = frames.top!.returnCursor
    frames.pop()
  }

  private func execute(_ branch: BranchInst) throws {
    let container = try valueContainer(of: branch.condition)
    guard let condition = (container as? PrimitiveValue)?.value as? Bool
      else { throw RuntimeError("'\(container)' is not a boolean value") }

    cursor = condition
      ? Cursor(in: cursor!.function, atBeginningOf: branch.thenLabel)
      : Cursor(in: cursor!.function, atBeginningOf: branch.elseLabel)
  }

  private func execute(_ jump: JumpInst) throws {
    cursor = Cursor(in: cursor!.function, atBeginningOf: jump.label)
  }

  private func valueContainer(of airValue: AIRValue) throws -> ValueContainer {
    switch airValue {
    case let cst as AIRConstant:
      return PrimitiveValue(cst.value as! PrimitiveType)

    case let fun as AIRFunction:
      return FunctionValue(function: fun)

    case let reg as AIRRegister:
      guard let reference = frames.top![reg.id]
        else { throw RuntimeError("invalid or uninitialized register '\(reg.id)'") }
      guard let valuePointer = reference.pointer
        else { throw RuntimeError("access to uninitialized memory") }
      return valuePointer.pointee

    default:
      unreachable()
    }
  }

  private func applyBuiltin(name: String, arguments: [AIRValue]) throws -> Reference? {
    switch name {
    case "__builtin_print_F_a2n":
      assert(arguments.count == 1)
      stdout.write(try "\(valueContainer(of: arguments[0]))\n")
      return nil

    case "__builtinIntblock_+_F_i2F_i2i":
      assert(arguments.count == 2)
      let lhs = (try valueContainer(of: arguments[0]) as! PrimitiveValue).value as! Int
      let rhs = (try valueContainer(of: arguments[1]) as! PrimitiveValue).value as! Int
      let res = PrimitiveValue(lhs + rhs)
      return Reference(to: ValuePointer(to: res), type: res.type)

    case "__builtinIntblock_-_F_i2F_i2i":
      assert(arguments.count == 2)
      let lhs = (try valueContainer(of: arguments[0]) as! PrimitiveValue).value as! Int
      let rhs = (try valueContainer(of: arguments[1]) as! PrimitiveValue).value as! Int
      let res = PrimitiveValue(lhs - rhs)
      return Reference(to: ValuePointer(to: res), type: res.type)

    case "__builtinIntblock_*_F_i2F_i2i":
      assert(arguments.count == 2)
      let lhs = (try valueContainer(of: arguments[0]) as! PrimitiveValue).value as! Int
      let rhs = (try valueContainer(of: arguments[1]) as! PrimitiveValue).value as! Int
      let res = PrimitiveValue(lhs * rhs)
      return Reference(to: ValuePointer(to: res), type: res.type)

    case "__builtinIntblock_<=_F_i2F_i2b":
      assert(arguments.count == 2)
      let lhs = (try valueContainer(of: arguments[0]) as! PrimitiveValue).value as! Int
      let rhs = (try valueContainer(of: arguments[1]) as! PrimitiveValue).value as! Int
      let res = PrimitiveValue(lhs < rhs)
      return Reference(to: ValuePointer(to: res), type: res.type)

    default:
      fatalError("unimplemented built-in function '\(name)'")
    }
  }

}
