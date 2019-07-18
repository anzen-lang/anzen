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

  /// The loaded functions.
  private var functions: [String: AIRFunction] = [:]
  /// The program cursor.
  private var cursor: Cursor?
  /// The stack frames.
  private var frames: Stack<Frame> = []

  public func load(unit: AIRUnit) {
    functions.merge(unit.functions, uniquingKeysWith: { _, rhs in rhs })
  }

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
    case let ty as AIRStructType:
      frames.top![inst.id] = StructInstance(type: ty)
    default:
      throw RuntimeError("no allocator for type '\(inst.type)'")
    }
  }

  private func execute(_ inst: MakeRefInst) throws {
    frames.top![inst.id] = Reference()
  }

  private func execute(_ inst: ExtractInst) throws {
    guard let object = try value(of: inst.source) as? StructInstance
      else { throw RuntimeError("cannot extract from '\(inst.source)'") }
    guard object.payload.count > inst.index
      else { throw RuntimeError("index is out of bound") }
    frames.top![inst.id] = object.payload[inst.index]
  }

  private func execute(_ inst: CopyInst) throws {
    guard let ref = frames.top![inst.target.id] as? Reference
      else { throw RuntimeError("invalid or uninitialized register '\(inst.target.id)'") }

    // FIXME: Call copy constructor.
    ref.value = try value(of: inst.source)
  }

  private func execute(_ inst: MoveInst) throws {
    guard let ref = frames.top![inst.target.id] as? Reference
      else { throw RuntimeError("invalid or uninitialized register '\(inst.target.id)'") }

    switch inst.source {
    case let cst as AIRConstant:
      ref.value = cst.value
    case let reg as AIRRegister:
      ref.value = try value(of: reg)
    default:
      throw RuntimeError("invalid r-value for move '\(inst.source)'")
    }
  }

  private func execute(_ inst: BindInst) throws {
    guard let ref = frames.top![inst.target.id] as? Reference
      else { throw RuntimeError("invalid or uninitialized register '\(inst.target.id)'") }

    switch inst.source {
    case let fn as AIRFunction:
      ref.value = fn
    case let reg as AIRRegister:
      frames.top![inst.target.id] = frames.top![reg.id]
    default:
      throw RuntimeError("invalid r-value for bind '\(inst.source)'")
    }
  }

  private func execute(_ inst: UnsafeCastInst) throws {
    let source = try value(of: inst.operand)

    // NOTE: Just as C++'s reinterpret_cast, unsafe_cast should actually be a noop. We may however
    // implement some assertion checks in the future.
    frames.top![inst.id] = source
  }

  private func execute(_ inst: ApplyInst) throws {
    // Retrieve the function to be called, and all its arguments.
    let fn: AIRFunction
    var args = inst.arguments
    switch try value(of: inst.callee) {
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
      let returnValue = try applyBuiltin(name: fn.name, arguments: args)
      if let value = returnValue {
        frames.top![inst.id] = value
      }
      return
    }

    // Prepare the next stack frame.
    var nextFrame = Frame(returnCursor: cursor, returnID: inst.id)
    for (i, arg) in (args).enumerated() {
      // Notice the offset, so as to reserve %0 for `self`.
      nextFrame[i + 1] = Reference(to: try value(of: arg))
    }
    frames.push(nextFrame)

    // Jump into the function.
    cursor = Cursor(atEntryOf: fn)
  }

  private func execute(_ inst: PartialApplyInst) throws {
    frames.top![inst.id] = Closure(function: inst.function, arguments: inst.arguments)
  }

  private func execute(_ inst: DropInst) throws {
    frames.top![inst.value.id] = nil
    // FIXME: Call destructors.
  }

  private func execute(_ inst: ReturnInst) throws {
    // Move the return value (if any) onto the return register.
    if let retval = inst.value {
      if frames.count > 1 {
        // Note that the register in which we're about to write isn't supposed to exist yet.
        frames[frames.count - 2][frames.top!.returnID!] = try value(of: retval)
      }

      // FIXME: If the return value is to be passed by reference, we should copy the box itself.
      // Note that implementing this functionality will most likely require an additional flag in
      // `ReturnInst` to indicate that the function returns a borrowed argument.
    }

    // Pop the current frame.
    cursor = frames.top!.returnCursor
    frames.pop()
  }

  private func execute(_ branch: BranchInst) throws {
    let condition = try value(of: branch.condition) as! Bool
    cursor = condition
      ? Cursor(in: cursor!.function, atBeginningOf: branch.thenLabel)
      : Cursor(in: cursor!.function, atBeginningOf: branch.elseLabel)
  }

  private func execute(_ jump: JumpInst) throws {
    cursor = Cursor(in: cursor!.function, atBeginningOf: jump.label)
  }

  private func value(of airValue: AIRValue) throws -> Any {
    switch airValue {
    case let cst as AIRConstant:
      return cst.value

    case let fun as AIRFunction:
      return fun

    case let reg as AIRRegister:
      if let ref = frames.top![reg.id] as? Reference {
        guard let val = ref.value
          else { throw RuntimeError("memory error") }
        return val
      } else if let val = frames.top![reg.id] {
        return val
      } else {
        throw RuntimeError("invalid or uninitialized register '\(reg.id)'")
      }

    default:
      unreachable()
    }
  }

  private func applyBuiltin(name: String, arguments: [AIRValue]) throws -> Any? {
    switch name {
    case "__builtin_print_F_a2n":
      assert(arguments.count == 1)
      stdout.write(try "\(value(of: arguments[0]))\n")
      return nil

    case "__builtinIntblock_+_F_i2F_i2i":
      assert(arguments.count == 2)
      let lhs = try value(of: arguments[0]) as! Int
      let rhs = try value(of: arguments[1]) as! Int
      return lhs + rhs

    case "__builtinIntblock_-_F_i2F_i2i":
      assert(arguments.count == 2)
      let lhs = try value(of: arguments[0]) as! Int
      let rhs = try value(of: arguments[1]) as! Int
      return lhs - rhs

    case "__builtinIntblock_*_F_i2F_i2i":
      assert(arguments.count == 2)
      let lhs = try value(of: arguments[0]) as! Int
      let rhs = try value(of: arguments[1]) as! Int
      return lhs * rhs

    case "__builtinIntblock_<=_F_i2F_i2b":
      assert(arguments.count == 2)
      let lhs = try value(of: arguments[0]) as! Int
      let rhs = try value(of: arguments[1]) as! Int
      return lhs < rhs

    default:
      fatalError("unimplemented built-in function '\(name)'")
    }
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

  init(type: AIRStructType) {
    self.type = type
    self.payload = type.members.map { _ in Reference() }
  }

  let type: AIRStructType
  let payload: [Any]

  var description: String {
    let members = zip(type.members.keys, payload)
      .map({ "\($0.0): \($0.1)" })
      .joined(separator: ", ")
    return "\(type)(\(members))"
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
