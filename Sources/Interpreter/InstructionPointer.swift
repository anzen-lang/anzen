import AnzenIR

/// An instruction pointer (a.k.a. a program counter).
///
/// An instruction pointer is an iterator on the instructions of an AIR function's block. Every
/// call to `next` produces the next instruction in the block, until all have been yielded. Note
/// that an instruction pointer does not deal with control flow. Instead, the interpreter must
/// modify the instruction pointer to handle jumps, branchs, calls and function results.
struct InstructionPointer: IteratorProtocol {

  /// The current function.
  var function: AIRFunction

  /// An iterator on the current block.
  var iterator: Array<AIRInstruction>.Iterator

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

  mutating func next() -> AIRInstruction? {
    return iterator.next()
  }

}
