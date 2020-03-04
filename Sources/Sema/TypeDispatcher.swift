import AST

final class TypeDispatcher: ASTVisitor {

  /// The set of visited declaration, used to handle forward declarations.
  ///
  /// As Anzen allows forward references to type and functions, there can be situations in which an
  /// identifier will be visited before its declaration. Thus, in order to avoid having to perform
  /// two visitor passes, declarations are visited directly when referring identifiers are. This
  /// set is then used to prevent infinite recursions, in case an identifier would be referred to
  /// the body of its own declaration (e.g. the declaration of a recursive function).
  ///
  /// Since Anzen only lets function be overloaded, type matching is only required to disambiguate
  /// between function declarations. Therefore, identifiers for other kinds of declarations need
  /// not to be inserted in this set.
  private var visitedDecls: Set<ObjectIdentifier> = []

  /// The type finalizer.
  private let finalizer: TypeFinalizer

  init(typeFinalizer: TypeFinalizer) {
    self.finalizer = typeFinalizer
  }

  // MARK:- ASTVisitor

  func visit(_ node: PropDecl) {
    node.type = finalizer.finalize(type: node.type!)
    node.traverse(with: self)
  }

  func visit(_ node: FunDecl) {
    guard !visitedDecls.contains(ObjectIdentifier(node))
      else { return }

    node.type = finalizer.finalize(type: node.type!)
    visitedDecls.insert(ObjectIdentifier(node))
    node.traverse(with: self)
  }

  func visit(_ node: ParamDecl) {
    node.type = finalizer.finalize(type: node.type!)
    node.traverse(with: self)
  }

  func visit(_ node: QualTypeSign) {
    node.type = finalizer.finalize(type: node.type!)
    node.traverse(with: self)
  }

  func visit(_ node: IdentSign) {
    node.type = node.type?.accept(transformer: finalizer)
    node.traverse(with: self)
  }

  func visit(_ node: NestedIdentSign) {
    node.type = node.type?.accept(transformer: finalizer)
    node.traverse(with: self)
  }

  func visit(_ node: ImplicitNestedIdentSign) {
    node.type = node.type?.accept(transformer: finalizer)
    node.traverse(with: self)
  }

  func visit(_ node: FunSign) {
    node.type = node.type?.accept(transformer: finalizer)
    node.traverse(with: self)
  }

  func visit(_ node: ParamSign) {
    node.type = finalizer.finalize(type: node.type!)
    node.traverse(with: self)
  }

  func visit(_ node: LambdaExpr) {
    node.type = finalizer.finalize(type: node.type!)
    node.traverse(with: self)
  }

  func visit(_ node: UnsafeCastExpr) {
    node.type = finalizer.finalize(type: node.type!)
    node.traverse(with: self)
  }

  func visit(_ node: SafeCastExpr) {
    node.type = finalizer.finalize(type: node.type!)
    node.traverse(with: self)
  }

  func visit(_ node: InfixExpr) {
    node.type = finalizer.finalize(type: node.type!)
    node.traverse(with: self)
  }

  func visit(_ node: PrefixExpr) {
    node.type = finalizer.finalize(type: node.type!)
    node.traverse(with: self)
  }

  func visit(_ node: CallExpr) {
    node.type = finalizer.finalize(type: node.type!)
    node.traverse(with: self)
  }

  func visit(_ node: CallArgExpr) {
    node.type = finalizer.finalize(type: node.type!)
    node.traverse(with: self)
  }

  func visit(_ node: IdentExpr) {
    node.type = finalizer.finalize(type: node.type!)
    node.traverse(with: self)

    // We identifying the declaration that corresponds to a given identifier by checking for type
    // matches. These require that both the identifier's type and that of the declarations to which
    // it might refer be fully formed (i.e. do not contain any type veriable).
    if node.referredDecls.count <= 1 {
      // Nothing to do if the declaration isn't overloaded.
      return
    }
    for decl in node.referredDecls {
      assert(decl is FunDecl, "bad overloaded declaration")
      decl.accept(visitor: self)
    }

    // Search for the declaration that matches the identifier's type.
    switch node.type!.bareType {
    case let funTy as FunType:
      node.referredDecls = node.referredDecls.filter { decl -> Bool in
        (decl as? FunDecl)?.type?.bareType == funTy
      }

    case let ty as BoundGenericType where ty.type is FunType:
      let funTy = (ty.type as! FunType).subst(ty.bindings)
      node.referredDecls = node.referredDecls.filter { decl -> Bool in
        if let declTy = (decl as? FunDecl)?.type?.bareType as? FunType {
          return declTy.subst(ty.bindings) == funTy
        }
        return true
      }

    default:
      assertionFailure("bad overloaded type")
    }

    assert(!node.referredDecls.isEmpty)
    if node.referredDecls.count != 1 {
      node.registerError(message: Issue.ambiguousFunctionUse(
        name: node.name,
        candidates: node.referredDecls as! [FunDecl]))
      node.referredDecls.removeSubrange(1...)
    }

    // Check for superfluous specialization arguments.
    let placeholders = (node.referredDecls[0] as! FunDecl).genericParams.map { $0.name }
    let superfluous = Set(node.specArgs.keys).subtracting(placeholders)
    for name in superfluous {
      node.registerWarning(message: Issue.superfluousSpecArg(name: name))
    }
  }

  public func visit(_ node: SelectExpr) {
    node.type = finalizer.finalize(type: node.type!)
    node.traverse(with: self)
  }

}
