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

  /// The stack frames.
  private var frames: Stack<[String: Box]> = []

  /// A stack that of program cursors.
  private var cursors: Stack<Cursor> = []

  /// The stack of return registers.
  ///
  /// When a function is called, we need to keep a pointer on the register in which the caller
  /// expects to get the return value.
  private var returnRegisters: Stack<String> = []

  public func load(unit: AIRUnit) {
    functions.merge(unit.functions, uniquingKeysWith: { _, rhs in rhs })
  }

  public func invoke(function: AIRFunction) {
    guard let (_, entry) = function.blocks.first
      else { fatalError("function does not have an entry block") }

    cursors.push(Cursor(function: function, iterator: entry.makeIterator()))
    frames.push([:])

    while let instruction = cursors.top?.next() {
      switch instruction {
      case let inst as NewRefInst : execute(inst)
      case let inst as CopyInst   : execute(inst)
      case let inst as MoveInst   : execute(inst)
      case let inst as BindInst   : execute(inst)
      case let inst as ApplyInst  : execute(inst)
      case let inst as DropInst   : execute(inst)
      case let inst as ReturnInst : execute(inst)
      default                     : unreachable()
      }
    }
  }

  private func execute(_ newRef: NewRefInst) {
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
    case let rvalue as NewRefInst:
      frames.top![move.target.name]!.value = frames.top![rvalue.name]!.value
    case let rvalue as ApplyInst:
      frames.top![move.target.name]!.value = frames.top![rvalue.name]!.value
    default:
      unreachable()
    }
  }

  private func execute(_ bind: BindInst) {
    switch bind.source {
    case let rvalue as NewRefInst:
      frames.top![bind.target.name] = frames.top![rvalue.name]
    case let rvalue as ApplyInst:
      frames.top![bind.target.name] = frames.top![rvalue.name]
    case let function as AIRFunction:
      frames.top![bind.target.name]!.value = function
    default:
      unreachable()
    }
  }

  private func execute(_ apply: ApplyInst) {
    let callee = value(of: apply.callee) as! AIRFunction
    switch callee.name! {
    case "print":
      let subject = value(of: apply.arguments[0])
      print(subject)

    default:
      // The callee isn't a user function, so have to prepare the next call frame.
      guard let (_, entry) = callee.blocks.first
        else { fatalError("function does not have an entry block") }

      // Create the return register in the current stack frame.
      let retref = Box(value: Null(), type: apply.type)
      frames.top![apply.name] = retref
      returnRegisters.push(apply.name)

      // Push the next stack frame.
      var frame: [String: Box] = [:]
      for (i, argument) in apply.arguments.enumerated() {
        frame[i.description] = Box(value: value(of: argument), type: argument.type)
      }
      frames.push(frame)

      // Change the program cursor.
      cursors.push(Cursor(function: callee, iterator: entry.makeIterator()))
    }
  }

  private func execute(_ drop: DropInst) {
    frames.top![drop.value.name] = nil
    // FIXME: Call destructors.
  }

  private func execute(_ ret: ReturnInst) {
    // Move the return value (if any) on the return register.
    if let retval = ret.value {
      frames[frames.count - 2][returnRegisters.top!]!.value = retval

      // FIXME: If the return value is to be passed by reference, we should copy the box itself.
      // Note that implementing this functionality will most likely require an additional flag in
      // `ReturnInst` to indicate that the function returns a borrowed argument.
    }

    // Restore the stacks.
    returnRegisters.pop()
    frames.pop()
    cursors.pop()
  }

  private func value(of airValue: AIRValue) -> Any {
    switch airValue {
    case let literal as AIRLiteral:
      return literal.value
    case let rvalue as NewRefInst:
      return frames.top![rvalue.name]!.value
    case let rvalue as ApplyInst:
      return frames.top![rvalue.name]!.value
    default:
      unreachable()
    }
  }

}

private struct Cursor {

  var function: AIRFunction
  var iterator: Array<AIRInstruction>.Iterator

  public mutating func next() -> AIRInstruction? {
    return iterator.next()
  }

}

private class Box {

  public init(value: Any, type: TypeBase) {
    self.value = value
    self.type = type
  }

  var value: Any
  let type: TypeBase

}

private struct Null {
}
