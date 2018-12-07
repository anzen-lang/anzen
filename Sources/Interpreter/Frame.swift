struct Frame {

  init(
    locals: [Int: Any] = [:],
    returnCursor: Cursor? = nil,
    returnID: Int? = nil)
  {
    self.locals = locals
    self.returnCursor = returnCursor
    self.returnID = returnID
  }

  /// The locals (included arguments) of the routine.
  var locals: [Int: Any]

  /// Returns the value of a frame's local.
  subscript(id: Int) -> Any? {
    get { return locals[id] }
    set { locals[id] = newValue }
  }

  /// The return cursor (i.e. where the interpreter is supposed to jump after the routine).
  let returnCursor: Cursor?
  /// The ID of the parent's local expecting the return value from this frame.
  let returnID: Int?

}
