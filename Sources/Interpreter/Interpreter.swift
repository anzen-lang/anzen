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

  /// The locals of the current frame.
  private var locals: [Int: Reference] {
    get {
      return frames.top!.locals
    }
    set {
      frames.top!.locals = newValue
    }
  }

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
      case let inst as AllocInst        : execute(inst)
      case let inst as MakeRefInst      : execute(inst)
      case let inst as ExtractInst      : try execute(inst)
      case let inst as CopyInst         : try execute(inst)
      case let inst as MoveInst         : try execute(inst)
      case let inst as BindInst         : try execute(inst)
      case let inst as UnsafeCastInst   : try execute(inst)
      case let inst as RefEqInst        : try execute(inst)
      case let inst as RefNeInst        : try execute(inst)
      case let inst as ApplyInst        : try execute(inst)
      case let inst as PartialApplyInst : try execute(inst)
      case let inst as DropInst         : try execute(inst)
      case let inst as ReturnInst       : try execute(inst)
      case let inst as BranchInst       : try execute(inst)
      case let inst as JumpInst         : try execute(inst)
      default:
        fatalError("unexpected instruction '\(instruction.instDescription)'")
      }
    }
  }

  private func execute(_ inst: AllocInst) {
    switch inst.type {
    case let type as AIRStructType:
      // Create a new unique reference on a struct instance.
      locals[inst.id] = Reference(
        to: ValuePointer(to: StructInstance(type: type)),
        type: type,
        state: .unique)

    default:
      fatalError("no allocator for type '\(inst.type)'")
    }
  }

  private func execute(_ inst: MakeRefInst) {
    // Create a new unallocated reference.
    locals[inst.id] = Reference(type: inst.type)
  }

  private func execute(_ inst: ExtractInst) throws {
    // Dereference the struct instance.
    guard let reference = locals[inst.source.id]
      else { fatalError("invalid or uninitialized register '\(inst.source.id)'") }

    switch reference.state {
    case .uninitialized:
      throw MemoryError("illegal access to uninitialized reference", at: inst.range)
    case .moved:
      throw MemoryError("illegal access to moved reference", at: inst.range)
    default:
      break
    }

    guard let instance = reference.pointer?.pointee as? StructInstance
      else { fatalError("register '\(inst.source.id)' does not stores a struct instance") }

    // Dereference the struct's member.
    guard instance.payload.count > inst.index
      else { fatalError("struct member index is out of bound") }

    locals[inst.id] = instance.payload[inst.index]
  }

  private func execute(_ inst: CopyInst) throws {
    // Dereference the source and make sure it is initialized.
    let source = dereference(value: inst.source)
    switch source.state {
    case .uninitialized:
      throw MemoryError("illegal access to uninitialized reference", at: inst.range)
    case .moved:
      throw MemoryError("illegal access to moved reference", at: inst.range)
    default:
      break
    }

    // Dereference the target.
    let target = dereference(register: inst.target)

    // Copy the source to the target.
    if let pointer = target.pointer {
      pointer.pointee = source.pointer!.pointee.copy()
    } else {
      target.pointer = ValuePointer(to: source.pointer!.pointee.copy())
      target.state = .unique
    }
  }

  private func execute(_ inst: MoveInst) throws {
    // Dereference the source and make sure it is unique.
    let source = dereference(value: inst.source)
    switch source.state {
    case .shared, .borrowed:
      throw MemoryError("cannot move non-unique reference", at: inst.range)
    case .uninitialized:
      throw MemoryError("illegal access to uninitialized reference", at: inst.range)
    case .moved:
      throw MemoryError("illegal access to moved reference", at: inst.range)
    case .unique:
      break
    }

    // Dereference the target.
    let target = dereference(register: inst.target)

    // Move the source to the target.
    source.state = .moved
    if let pointer = target.pointer {
      pointer.pointee = source.pointer!.pointee
    } else {
      target.pointer = ValuePointer(to: source.pointer!.pointee)
      target.state = .unique
    }
  }

  private func execute(_ inst: BindInst) throws {
    // Make sure the source is not a constant.
    guard !(inst.source is AIRConstant)
      else { throw MemoryError("cannot form an alias on a constant", at: inst.range) }

    // Dereference the source and make sure it is initialized.
    let source = dereference(value: inst.source)
    switch source.state {
    case .uninitialized:
      throw MemoryError("illegal access to uninitialized reference", at: inst.range)
    case .moved:
      throw MemoryError("illegal access to moved reference", at: inst.range)
    default:
      break
    }

    // Dereference the target and make sure it is not shared.
    let target = dereference(register: inst.target)
    if case .shared = target.state {
      throw MemoryError("cannot reassign a shared reference", at: inst.range)
    }

    // Form the alias.
    target.pointer = source.pointer

    // Return the uniqueness fragment to its owner, if any.
    if case .borrowed(let owner) = target.state {
      guard case .shared(let count) = owner.state else { unreachable() }
      owner.state = count > 1
        ? .shared(count: count - 1)
        : .unique
    }

    // Update the source and target references' capabilities.
    switch source.state {
    case .unique:
      // The source is unique, so we borrow directly from it.
      source.state = .shared(count: 1)
      target.state = .borrowed(owner: source)

    case .shared(let count):
      // The source is owner and already shared, so we borrow directly from it.
      source.state = .shared(count: count + 1)
      target.state = .borrowed(owner: source)

    case .borrowed(let owner):
      // The source is borrowed, so we borrow from its owner.
      guard case .shared(let count) = owner.state else { unreachable() }
      owner.state = .shared(count: count + 1)
      target.state = .borrowed(owner: owner)

    default:
      unreachable()
    }
  }

  private func execute(_ inst: UnsafeCastInst) throws {
    // Dereference the operand and make sure it is initialized.
    let operand = dereference(value: inst.operand)
    switch operand.state {
    case .uninitialized:
      throw MemoryError("illegal access to uninitialized reference", at: inst.range)
    case .moved:
      throw MemoryError("illegal access to moved reference", at: inst.range)
    default:
      break
    }

    // Optimization opportunity:
    // Just as C++'s reinterpret_cast, unsafe_cast should actually be a noop. We may however
    // implement some assertion checks in the future.
    locals[inst.id] = Reference(to: operand.pointer, type: inst.type, state: operand.state)
  }

  private func execute(_ inst: RefEqInst) throws {
    let container = PrimitiveValue(areSameReferences(inst.lhs, inst.rhs))
    locals[inst.id] = Reference(to: ValuePointer(to: container), type: .bool, state: .unique)
  }

  private func execute(_ inst: RefNeInst) throws {
    let container = PrimitiveValue(!areSameReferences(inst.lhs, inst.rhs))
    locals[inst.id] = Reference(to: ValuePointer(to: container), type: .bool, state: .unique)
  }

  private func execute(_ inst: ApplyInst) throws {
    // Dereference the callee and make sure it is initialized.
    let callee = dereference(value: inst.callee)
    switch callee.state {
    case .uninitialized:
      throw MemoryError("illegal access to uninitialized reference", at: inst.range)
    case .moved:
      throw MemoryError("illegal access to moved reference", at: inst.range)
    default:
      break
    }

    guard let container = callee.pointer?.pointee as? FunctionValue
      else { fatalError("'\(callee)' is not a function") }
    let function = container.function
    let arguments = container.closure + inst.arguments

    // Handle built-in funtions.
    if function.name.starts(with: "__") {
      locals[inst.id] = try applyBuiltin(name: function.name, arguments: arguments)
      return
    }

    // Prepare the next stack frame. Notice the offset, so as to reserve %0 for `self`.
    var nextFrame = Frame(returnInstructionPointer: instructionPointer, returnID: inst.id)
    for (i, argument) in arguments.enumerated() {
      switch argument {
      case let constant as AIRConstant:
        // Create a new unique reference.
        let value = PrimitiveValue(constant.value as! PrimitiveType)
        nextFrame[i + 1] = Reference(
          to: ValuePointer(to: value),
          type: argument.type,
          state: .unique)

      case let function as AIRFunction:
        // Create a new borrowed reference.
        let value = FunctionValue(function: function)
        nextFrame[i + 1] = Reference(
          to: ValuePointer(to: value),
          type: argument.type,
          state: .borrowed(owner: StaticReference.get))

      case let reg as AIRRegister:
        // Take the reference, as is.
        nextFrame[i + 1] = locals[reg.id]

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
    locals[inst.id] = Reference(to: ValuePointer(to: value), type: inst.type, state: .unique)
  }

  private func execute(_ inst: DropInst) throws {
    frames.top![inst.value.id] = nil
    // FIXME: Call destructors.
  }

  private func execute(_ inst: ReturnInst) throws {
    // Assign the return value (if any) onto the return register.
    if let returnValue = inst.value {
      // Dereference the return value.
      let returnReference = dereference(value: returnValue)
      if frames.count > 1 {
        frames[frames.count - 2][frames.top!.returnID!] = returnReference
      }
    }

    // Pop the current frame.
    instructionPointer = frames.top!.returnInstructionPointer
    frames.pop()
  }

  private func execute(_ branch: BranchInst) throws {
    // Dereference the condition.
    let reference = dereference(value: branch.condition)
    guard let condition = (reference.pointer?.pointee as? PrimitiveValue)?.value as? Bool
      else { fatalError("'\(reference)' is not a boolean value") }

    instructionPointer = condition
      ? InstructionPointer(in: instructionPointer!.function, atBeginningOf: branch.thenLabel)
      : InstructionPointer(in: instructionPointer!.function, atBeginningOf: branch.elseLabel)
  }

  private func execute(_ jump: JumpInst) throws {
    instructionPointer = InstructionPointer(
      in: instructionPointer!.function,
      atBeginningOf: jump.label)
  }

  private func dereference(value airValue: AIRValue) -> Reference {
    switch airValue {
    case let register as AIRRegister:
      return dereference(register: register)

    case let constant as AIRConstant:
      let container = PrimitiveValue(constant.value as! PrimitiveType)
      return Reference(to: ValuePointer(to: container), type: container.type, state: .unique)

    case let function as AIRFunction:
      let container = FunctionValue(function: function)
      return Reference(to: ValuePointer(to: container), type: container.type, state: .unique)

    case is AIRNull:
      return Reference(type: .anything)

    default:
      unreachable()
    }
  }

  private func dereference(register airRegister: AIRRegister) -> Reference {
    guard let reference = locals[airRegister.id]
      else { fatalError("invalid or uninitialized register '\(airRegister.id)'") }
    return reference
  }

  // MARK: Built-in functions

  /// Computes reference identity.
  private func areSameReferences(_ lhs: AIRValue, _ rhs: AIRValue) -> Bool {
    let leftPointer: ValuePointer?
    switch lhs {
    case is AIRNull:
      leftPointer = nil
    case let register as AIRRegister:
      leftPointer = locals[register.id]?.pointer
    default:
      return false
    }

    let rightPointer: ValuePointer?
    switch rhs {
    case is AIRNull:
      rightPointer = nil
    case let register as AIRRegister:
      rightPointer = locals[register.id]?.pointer
    default:
      return false
    }

    return leftPointer === rightPointer
  }

  /// Applies a built-in function.
  private func applyBuiltin(name: String, arguments: [AIRValue]) throws -> Reference? {
    guard let function = builtinFunctions[name]
      else { fatalError("unimplemented built-in function '\(name)'") }

    let argumentContainers = arguments
      .map(dereference)
      .map({ $0.pointer!.pointee })
    return try function(argumentContainers)
  }

  private typealias BuiltinFunction = ([ValueContainer?]) throws -> Reference?

  private lazy var builtinFunctions: [String: BuiltinFunction] = {
    var result: [String: BuiltinFunction] = [:]

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
  return Reference(to: ValuePointer(to: res), type: res.type, state: .unique)
}
