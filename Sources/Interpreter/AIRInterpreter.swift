import AST
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

  private func execute(_ newRef: AllocInst) {
    frames.top![newRef.name] = Box(value: Null(), type: newRef.type)
  }

  private func execute(_ copy: CopyInst) {
    // FIXME: Call copy constructor.
    frames.top![copy.target.name]!.value = value(of: copy.source)
  }

  private func execute(_ move: MoveInst) {
    switch move.source {
    case let literal as AIRLiteral:
      frames.top![move.target.name]!.value = literal.value
    case let reg as AIRRegister:
      frames.top![move.target.name]!.value = frames.top![reg.name]!.value
    default:
      unreachable()
    }
  }

  private func execute(_ bind: BindInst) {
    switch bind.source {
    case let fn as AIRFunction:
      frames.top![bind.target.name]!.value = fn
    case let reg as AIRRegister:
      frames.top![bind.target.name] = frames.top![reg.name]
    default:
      unreachable()
    }
  }

  private func execute(_ apply: ApplyInst) {
    // Retrieve the function to be called, and all its arguments.
    let fn: AIRFunction
    var args = apply.arguments
    switch value(of: apply.callee) {
    case let thin as AIRFunction:
      fn = thin
    case let thick as AIRClosure:
      fn = thick.function
      args = thick.arguments + args
    default:
      unreachable()
    }

    // Handle built-in funtions.
    guard !fn.name.starts(with: "__builtin") else {
      let returnValue = applyBuiltin(name: fn.name, arguments: args)
      if let value = returnValue {
        frames.top![apply.name] = Box(value: value, type: apply.type)
      }
      return
    }

    // Prepare the next stack frame.
    frames.top![apply.name] = Box(value: Null(), type: apply.type)
    var nextFrame = Frame(returnCursor: cursor, returnName: apply.name)
    for (i, arg) in apply.arguments.enumerated() {
      nextFrame["\(i)"] = Box(value: value(of: arg), type: arg.type)
    }
    frames.push(nextFrame)

    // Jump into the function.
    cursor = Cursor(atEntryOf: fn)
  }

  private func execute(_ partialApply: PartialApplyInst) {
    frames.top![partialApply.name] = Box(
      value: AIRClosure(
        function: partialApply.function,
        arguments: partialApply.arguments,
        type: partialApply.type as! FunctionType),
      type: partialApply.type)
  }

  private func execute(_ drop: DropInst) {
    frames.top![drop.value.name] = nil
    // FIXME: Call destructors.
  }

  private func execute(_ ret: ReturnInst) {
    // Move the return value (if any) onto the return register.
    if let retval = ret.value {
      if frames.count > 1 {
        frames[frames.count - 2][frames.top!.returnName!]!.value = value(of: retval)
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
    case let literal as AIRLiteral:
      return literal.value

    case let register as AIRRegister:
      guard let frame = frames.top
        else { fatalError("trying to read a register outside of a frame") }
      guard let box = frame[register.name]
        else { fatalError("invalid register '\(register.name)'") }
      return box.value

    case let closure as AIRClosure:
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

class Box {

  public init(value: Any, type: TypeBase) {
    self.value = value
    self.type = type
  }

  var value: Any
  let type: TypeBase

}

private struct Null {
}
