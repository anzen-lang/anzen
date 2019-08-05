/// An object that specifies a declaration context.
///
/// A declaration context refers to a region (a.k.a. lexical scope) in which entities, such as
/// types or functions can be declared.
public protocol DeclContext: AnyObject {

  /// The containing declaration context.
  var parent: DeclContext? { get }
  /// The declarations contained in this context.
  var decls: [Decl] { get set }

  /// Returns whether this declaration context is enclosed if the given one.
  func isEnclosed(in other: DeclContext) -> Bool

  /// Returns whether this declaration context is enclosing the given one.
  func isEnclosing(_ other: DeclContext) -> Bool

}

extension DeclContext {

  public func isEnclosed(in other: DeclContext) -> Bool {
    var parent = self.parent
    while parent != nil {
      if other === parent {
        return true
      }
      parent = parent!.parent
    }
    return false
  }

  /// Returns whether this scope is an ancestor of the given one.
  public func isEnclosing(_ other: DeclContext) -> Bool {
    return other.isEnclosed(in: self)
  }

}
