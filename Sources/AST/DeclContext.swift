/// An object that specifies a declaration context.
///
/// A declaration context refers to a region (a.k.a. lexical scope) in which entities, such as
/// types or functions can be declared.
public protocol DeclContext: AnyObject {

  /// The containing declaration context.
  var parent: DeclContext? { get }
  /// The declarations contained in this context.
  var decls: [Decl] { get set }

}

extension DeclContext {

  /// The named declarations contained in this context.
  public var namedDecls: [NamedDecl] {
    return decls.compactMap({ $0 as? NamedDecl })
  }

  public func firstDecl(named name: String) -> NamedDecl? {
    for decl in decls {
      if let namedDecl = decl as? NamedDecl, namedDecl.name == name {
        return namedDecl
      }
    }
    return nil
  }

  public func allDecls(named name: String) -> [NamedDecl] {
    return decls.filter { ($0 as? NamedDecl)?.name == name } as! [NamedDecl]
  }

  /// Returns whether this declaration context is enclosed if the given one.
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
