/// A handle on a runtime object (e.g. a pointer to a primitive value).
protocol ObjectHandle {
}

struct Frame {

  init(
    locals: [Int: Reference] = [:],
    returnCursor: Cursor? = nil,
    returnID: Int? = nil)
  {
    self.locals = locals
    self.returnCursor = returnCursor
    self.returnID = returnID
  }

  /// The locals (included arguments) of the routine.
  var locals: [Int: Reference]

  /// Returns the value of a frame's local.
  subscript(id: Int) -> Reference? {
    get { return locals[id] }
    set { locals[id] = newValue }
  }

  /// The return cursor (i.e. where the interpreter is supposed to jump after the routine).
  let returnCursor: Cursor?
  /// The ID of the parent's local expecting the return value from this frame.
  let returnID: Int?

}
