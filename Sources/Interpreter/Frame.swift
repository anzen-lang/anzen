struct Frame {

  init(
    locals: [String: Any] = [:],
    returnCursor: Cursor? = nil,
    returnName: String? = nil)
  {
    self.locals = locals
    self.returnCursor = returnCursor
    self.returnName = returnName
  }

  /// The locals (included arguments) of the routine.
  var locals: [String: Any]

  /// Returns the value of a frame's local.
  subscript(name: String) -> Any? {
    get { return locals[name] }
    set { locals[name] = newValue }
  }

  /// The return cursor (i.e. where the interpreter is supposed to jump after the routine).
  let returnCursor: Cursor?
  /// The name of the parent's local expecting the return value from this frame.
  let returnName: String?

}
