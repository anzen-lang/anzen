import SystemKit
import Utils

/// An interpreter for AIR code.
///
/// - Note: This interpreter operates under the assumption that the AIR units it is given are
///   correct with respect to type checking and borrow checking, and will unrecoverably fail if
///   that's not the case.
public class AIRInterpreter {

  public init() {}

  /// The loaded functions.
  private var functions: [String: AIRFunction] = [:]

  /// The program cursor.
  private var cursor: Cursor?
  /// The stack frames.
  private var frames: Stack<Frame> = []

  public func load(unit: AIRUnit) {
    functions.merge(unit.functions, uniquingKeysWith: { _, rhs in rhs })
  }

  public func invoke(function: AIRFunction) {
    cursor = Cursor(atEntryOf: function)
    frames.push(Frame())

    while let instruction = cursor?.next() {
      switch instruction {
      case let inst as AllocInst        : execute(inst)
      case let inst as MakeRefInst      : execute(inst)
      case let inst as CopyInst         : execute(inst)
      case let inst as MoveInst         : execute(inst)
      case let inst as BindInst         : execute(inst)
      case let inst as ApplyInst        : execute(inst)
      case let inst as PartialApplyInst : execute(inst)
      case let inst as DropInst         : execute(inst)
      case let inst as ReturnInst       : execute(inst)
      case let inst as BranchInst       : execute(inst)
      case let inst as JumpInst         : execute(inst)
      default                           : unreachable()
      }
    }
  }

  private func panic(_ message: String) -> Never {
    System.err.print("Fatal error: \(message)")
    System.exit(status: 1)
  }

  private func execute(_ inst: AllocInst) {
    switch inst.type {
    case let ty as AIRStructType:
      frames.top![inst.name] = StructInstance(
        payload: Array(repeating: Reference(), count: ty.elements.count))
    default:
      panic("no allocator for type '\(inst.type)'")
    }
  }

  private func execute(_ inst: MakeRefInst) {
    frames.top![inst.name] = Reference()
  }

  private func execute(_ inst: CopyInst) {
    guard let ref = frames.top![inst.target.name] as? Reference
      else { panic("invalid or uninitialized register '\(inst.target.name)'") }

    // FIXME: Call copy constructor.
    ref.value = value(of: inst.source)
  }

  private func execute(_ inst: MoveInst) {
    guard let ref = frames.top![inst.target.name] as? Reference
      else { panic("invalid or uninitialized register '\(inst.target.name)'") }

    switch inst.source {
    case let cst as AIRConstant:
      ref.value = cst.value
    case let reg as AIRRegister:
      ref.value = value(of: reg)
    default:
      panic("invalid r-value for move '\(inst.source)'")
    }
  }

  private func execute(_ inst: BindInst) {
    guard let ref = frames.top![inst.target.name] as? Reference
      else { panic("invalid or uninitialized register '\(inst.target.name)'") }

    switch inst.source {
    case let fn as AIRFunction:
      ref.value = fn
    case let reg as AIRRegister:
      frames.top![inst.target.name] = frames.top![reg.name]
    default:
      panic("invalid r-value for bind '\(inst.source)'")
    }
  }

  private func execute(_ inst: ApplyInst) {
    // Retrieve the function to be called, and all its arguments.
    let fn: AIRFunction
    var args = inst.arguments
    switch value(of: inst.callee) {
    case let thin as AIRFunction:
      fn = thin
    case let thick as Closure:
      fn = thick.function
      args = thick.arguments + args
    default:
      unreachable()
    }

    // Handle built-in funtions.
    guard !fn.name.starts(with: "__builtin") else {
      let returnValue = applyBuiltin(name: fn.name, arguments: args)
      if let value = returnValue {
        frames.top![inst.name] = value
      }
      return
    }

    // Prepare the next stack frame.
    var nextFrame = Frame(returnCursor: cursor, returnName: inst.name)
    for (i, arg) in (args + inst.arguments).enumerated() {
      nextFrame["\(i)"] = Reference(to: value(of: arg))
    }
    frames.push(nextFrame)

    // Jump into the function.
    cursor = Cursor(atEntryOf: fn)
  }

  private func execute(_ inst: PartialApplyInst) {
    frames.top![inst.name] = Closure(function: inst.function, arguments: inst.arguments)
  }

  private func execute(_ inst: DropInst) {
    frames.top![inst.value.name] = nil
    // FIXME: Call destructors.
  }

  private func execute(_ inst: ReturnInst) {
    // Move the return value (if any) onto the return register.
    if let retval = inst.value {
      if frames.count > 1 {
        // Note that the register in which we're about to write isn't supposed to exist yet.
        frames[frames.count - 2][frames.top!.returnName!] = value(of: retval)
      }

      // FIXME: If the return value is to be passed by reference, we should copy the box itself.
      // Note that implementing this functionality will most likely require an additional flag in
      // `ReturnInst` to indicate that the function returns a borrowed argument.
    }

    // Pop the current frame.
    cursor = frames.top!.returnCursor
    frames.pop()
  }

  private func execute(_ branch: BranchInst) {
    let condition = value(of: branch.condition) as! Bool
    cursor = condition
      ? Cursor(in: cursor!.function, atBeginningOf: branch.thenLabel)
      : Cursor(in: cursor!.function, atBeginningOf: branch.elseLabel)
  }

  private func execute(_ jump: JumpInst) {
    cursor = Cursor(in: cursor!.function, atBeginningOf: jump.label)
  }

  private func value(of airValue: AIRValue) -> Any {
    switch airValue {
    case let cst as AIRConstant:
      return cst.value

    case let reg as AIRRegister:
      if let ref = frames.top![reg.name] as? Reference {
        guard let val = ref.value
          else { panic("memory error") }
        return val
      } else if let val = frames.top![reg.name] {
        return val
      } else {
        panic("invalid or uninitialized register '\(reg.name)'")
      }

    case let closure as Closure:
      return closure

    default:
      unreachable()
    }
  }

  private func applyBuiltin(name: String, arguments: [AIRValue]) -> Any? {
    switch name {
    case "__builtin_print_F_a2n":
      assert(arguments.count == 1)
      print(value(of: arguments[0]))
      return nil

    case "__builtinIntblock_+_F_i2F_i2i":
      assert(arguments.count == 2)
      let lhs = value(of: arguments[0]) as! Int
      let rhs = value(of: arguments[1]) as! Int
      return lhs + rhs

    case "__builtinIntblock_-_F_i2F_i2i":
      assert(arguments.count == 2)
      let lhs = value(of: arguments[0]) as! Int
      let rhs = value(of: arguments[1]) as! Int
      return lhs - rhs

    case "__builtinIntblock_*_F_i2F_i2i":
      assert(arguments.count == 2)
      let lhs = value(of: arguments[0]) as! Int
      let rhs = value(of: arguments[1]) as! Int
      return lhs * rhs

    case "__builtinIntblock_<=_F_i2F_i2b":
      assert(arguments.count == 2)
      let lhs = value(of: arguments[0]) as! Int
      let rhs = value(of: arguments[1]) as! Int
      return lhs < rhs

    default:
      fatalError("unimplemented built-in function '\(name)'")
    }
  }

}

struct Cursor {

  init(in function: AIRFunction, atBeginningOf label: String) {
    guard let block = function.blocks[label]
      else { fatalError("function does not have block labeled '\(label)'") }
    self.function = function
    self.iterator = block.makeIterator()
  }

  init(atEntryOf function: AIRFunction) {
    guard let (_, block) = function.blocks.first
      else { fatalError("function does not have an entry block") }
    self.function = function
    self.iterator = block.makeIterator()
  }

  var function: AIRFunction
  var iterator: Array<AIRInstruction>.Iterator

  public mutating func next() -> AIRInstruction? {
    return iterator.next()
  }

}

/// Represetns a reference.
private class Reference: CustomStringConvertible {

  init(to value: Any? = nil) {
    assert(!(value is Reference))
    self.value = value
  }

  var value: Any? {
    didSet { assert(!(value is Reference)) }
  }

  var description: String {
    return "\(value ?? "null")"
  }

}

/// Represents a struct type instance.
private struct StructInstance: CustomStringConvertible {

  let payload: [Any]

  var description: String {
    let members = payload.map({ "\($0)" }).joined(separator: ", ")
    return "{\(members)}"
  }

}

/// Represents a function closure
private struct Closure: CustomStringConvertible {

  let function: AIRFunction
  let arguments: [AIRValue]

  var description: String {
    return "(Function)"
  }

}
