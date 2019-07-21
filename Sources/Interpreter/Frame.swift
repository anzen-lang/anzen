/// A call frame (a.k.a. a stack frame).
///
/// A frame contains the references of the arguments and local variables of the function being
/// called, as well as some additional data required to handle return values and restore the
/// instruction pointer once the function returns.
struct Frame {

  /// The locals (included arguments) of the routine.
  var locals: [Int: Reference]

  /// The return instruction pointer (i.e. where the interpreter is supposed to jump after the
  // routine returns).
  let returnInstructionPointer: InstructionPointer?

  /// The ID of the parent's local expecting the return value from this frame.
  let returnID: Int?

  init(
    locals: [Int: Reference] = [:],
    returnInstructionPointer: InstructionPointer? = nil,
    returnID: Int? = nil)
  {
    self.locals = locals
    self.returnInstructionPointer = returnInstructionPointer
    self.returnID = returnID
  }

  /// Returns the value of a frame's local.
  subscript(id: Int) -> Reference? {
    get { return locals[id] }
    set { locals[id] = newValue }
  }

}
