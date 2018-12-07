import AnzenIR

struct Cursor: IteratorProtocol {

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

  mutating func next() -> AIRInstruction? {
    return iterator.next()
  }

}
