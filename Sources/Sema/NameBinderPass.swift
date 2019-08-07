import AST

/// A module pass that binds identifiers to their declaration contexts.
///
/// This pass takes place immediately after parsing, and links value and type identifiers to their
/// declaration context. Because of overloading, the actual declaration node to which an identifier
/// refers cannot be decided before type inference completes.
public struct NameBinderPass {

  /// The compiler context.
  public let context: CompilerContext
  /// The module being processed.
  public let module: Module

  public init(module: Module, context: CompilerContext) {
    assert(module.state == .parsed, "module has not been parsed yet")
    self.context = context
    self.module = module
  }

  public func process() {
    let binder = Binder(topLevelDeclContext: module, context: context)
    for decl in module.decls {
      decl.accept(visitor: binder)
    }
  }

  // MARK: Internal visitor

  private final class Binder: ASTVisitor {

    /// The compiler context.
    public let context: CompilerContext

    /// An array that keeps track of the property or parameter declaration being visited
    ///
    /// This array keeps track of the property and parameter declarations being being visited while
    /// resolving the declaration context of the identifiers in their initializer or default value.
    /// Consider for instance the following Anzen program:
    ///
    /// ```anzen
    /// let x <- 0
    /// fun f() { let x <- x }
    /// ```
    ///
    /// The identifier `x` inside function `f` should be bound to the outermost declaration rather
    /// than that in `f`'s body.
    var declBeingVisited: Set<ObjectIdentifier> = []
    /// The current declaration context.
    var currentDeclContext: DeclContext

    init(topLevelDeclContext: Module, context: CompilerContext) {
      self.context = context
      self.currentDeclContext = topLevelDeclContext
    }

    func visit(_ node: PropDecl) {
      declBeingVisited.insert(ObjectIdentifier(node))
      node.traverse(with: self)
      declBeingVisited.remove(ObjectIdentifier(node))
    }

    func visit(_ node: FunDecl) {
      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

    func visit(_ node: ParamDecl) {
      // Parameters are considered declared all at once. Hence, all adjacent parameter declarations
      // are added to the set of visited declarations.
      let paramDeclIDs = node.declContext!.decls.compactMap {
        ($0 as? ParamDecl).map(ObjectIdentifier.init)
      }

      declBeingVisited.formUnion(paramDeclIDs)
      node.traverse(with: self)
      declBeingVisited.subtract(paramDeclIDs)
    }

    func visit(_ node: InterfaceDecl) {
      node.decls.append(ProxiedNamedDecl(node, name: "Self"))
      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

    func visit(_ node: StructDecl) {
      node.decls.append(ProxiedNamedDecl(node, name: "Self"))
      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

    func visit(_ node: UnionDecl) {
      node.decls.append(ProxiedNamedDecl(node, name: "Self"))
      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

    func visit(_ node: TypeExtDecl) {
      func isExtendableTypeDecl(_ decl: NamedDecl) -> Bool {
        return (decl is NominalTypeDecl)
            || (decl is ProxiedNamedDecl)
            || (decl is BuiltinTypeDecl)
      }

      // Resolve the declaration of `Self`.
      if let ident = node.type as? IdentSign {
        let decls = currentDeclContext.lookup(
          unqualifiedName: ident.name, inCompilerContext: context)
        if decls.isEmpty {
          ident.registerError(message: Issue.unboundIdentifier(name: ident.name))
        } else if !isExtendableTypeDecl(decls[0]) {
          ident.registerError(message: Issue.invalidTypeIdentifier(name: ident.name))
        }

        assert(decls.count == 1, "bad extension on overloaded type name")
        node.decls.append(ProxiedNamedDecl(decls[0], name: "Self"))
      }

      node.type.accept(visitor: self)
      inDeclContext(node) {
        node.body.accept(visitor: self)
      }
    }

    func visit(_ node: PrefixExpr) {
      // The declaration context of the expression's operator determined before type inference.
      node.operand.accept(visitor: self)
    }

    func visit(_ node: InfixExpr) {
      // The declaration context of the expression's operator determined before type inference.
      node.lhs.accept(visitor: self)
      node.rhs.accept(visitor: self)
    }

    func visit(_ node: IdentExpr) {
      linkToDeclContext(node)
      node.traverse(with: self)
    }

    func visit(_ node: SelectExpr) {
      // The declaration context of a select's ownee cannot be determined before type inference.
      node.owner.accept(visitor: self)
    }

    func visit(_ node: ImplicitSelectExpr) {
      // The declaration context of a select's ownee cannot be determined before type inference.
    }

    func visit(_ node: BraceStmt) {
      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

    func visit(_ node: IdentSign) {
      linkToDeclContext(node)
      node.traverse(with: self)
    }

    // MARK: Helpers

    private func linkToDeclContext<Ident>(_ node: Ident) where Ident: Identifier {
      // Find the closest declaration context in which the identifier is declared.
      var declContext: DeclContext? = currentDeclContext
      while declContext != nil {
        if let decl = declContext!.firstDecl(named: node.name) {
          if !declBeingVisited.contains(ObjectIdentifier(decl)) {
            if !decl.isOverloadable {
              // If the declaration isn't overloadable, we can already link it to the identifier.
              node.decl = decl
            }

            // Either way, we link the declaration's context to the identifier.
            node.declContext = declContext!
            return
          }
        }
        declContext = declContext!.parent
      }

      // If the identifier couldn't be found in any context, then it may be a built-in type name.
      if CompilerContext.builtinTypeNames.contains(node.name) {
        node.decl = context.builtinModule.firstDecl(named: node.name)
        node.declContext = context.builtinModule
        return
      }

      // The identifier's unbound.
      node.registerError(message: Issue.unboundIdentifier(name: node.name))
    }

    private func inDeclContext(_ declContext: DeclContext, run block: () -> Void) {
      let previousDeclContext = currentDeclContext
      currentDeclContext = declContext
      block()
      currentDeclContext = previousDeclContext
    }

  }

}

private protocol Identifier: ASTNode {

  var name: String { get }
  var decl: NamedDecl? { get set }
  var declContext: DeclContext? { get set }

}

extension IdentExpr: Identifier {
}

extension IdentSign: Identifier {
}

// MARK: - Identifier lookup

extension DeclContext {

  /// Search for a declaration that matches the given unqualified identifier in this declaration
  /// context and its parents.
  ///
  /// This method may produce multiple results in cased the given identifier refers to overloaded
  /// declarations (i.e. function definitions). In this case, declarations are returned from the
  /// innermost to the outermost context.
  func lookup(unqualifiedName: String, inCompilerContext context: CompilerContext) -> [NamedDecl] {
    var results: [NamedDecl] = []
    var declContext: DeclContext? = self
    while declContext != nil {
      // Find the declarations whose name matches the given unqualified identifier.
      let matches = declContext!.allDecls(named: unqualifiedName)
      if !matches.isEmpty {
        if !matches[0].isOverloadable {
          // If the match is not overloadable, keep it only if its the first and stop searching.
          assert(matches.count == 1)
          if results.isEmpty {
            results.append(matches[0])
          }
          return results
        } else {
          // If the matches are overloadable, keep them and continue searching for other
          // overloadable matches in enclosing contexts.
          results.append(contentsOf: matches)
        }
      }
      declContext = declContext!.parent
    }

    // If there aren't any results, look for built-in symbols.
    if results.isEmpty && CompilerContext.builtinTypeNames.contains(unqualifiedName) {
      return [context.builtinModule.firstDecl(named: unqualifiedName)!]
    } else {
      return results
    }
  }

}

extension NominalTypeDecl {

  /// Finds all extensions of this type declaration in the given module.
  func findExtensions(in searchModule: Module) -> [TypeExtDecl] {
    // Compute this type's qualified name.
    var parentContext = declContext!
    var qName = [name]
    while parentContext.parent != nil {
      if let nominalTypeDecl = (parentContext as? BraceStmt)?.parent as? NominalTypeDecl {
        qName.append(nominalTypeDecl.name)
        parentContext = nominalTypeDecl.parent!
      } else {
        // The nominal type is nested in a non-type context, so it can't be extended.
        return []
      }
    }
    assert(parentContext === module)

    // Search for all extensions.
    if qName.count == 1 {
      // The type isn't nested, so we can lookup its name directly.
      return searchModule.decls.compactMap { decl in
        ((decl as? TypeExtDecl)?.type as? IdentSign)?.name == qName[0] ? decl : nil
      } as! [TypeExtDecl]
    } else {
      var extDecls: [TypeExtDecl] = []
      // The type is nested, so we need to match its qualified name with a nested type signature.
      for extDecl in searchModule.decls
        where (extDecl as? TypeExtDecl)?.type is NestedIdentSign
      {
        var sign = (extDecl as! TypeExtDecl).type
        var i = 0
        while let nestedIdent = sign as? NestedIdentSign {
          guard nestedIdent.ownee.name == qName[i]
            else { break }
          sign = nestedIdent.owner
          i += 1
        }

        if i == qName.count {
          extDecls.append(extDecl as! TypeExtDecl)
        }
      }
      return extDecls
    }
  }

  /// Searches for a member declarations that matches the given unqualified identifier.
  ///
  /// This method may produce multiple results in cased the given identifier refers to overloaded
  /// declarations (i.e. function definitions). In this case, declarations are returned from the
  /// innermost to the outermost contexts.
  func lookup(memberName: String, inCompilerContext context: CompilerContext) -> [NamedDecl]
  {
    // Initialize or update the member lookup table as required.
    if memberLookupTable == nil {
      memberLookupTable = MemberLookupTable(generationNumber: context.currentGeneration)
      for member in decls where member is NamedDecl {
        memberLookupTable!.insert(member: member as! NamedDecl)
      }

      // Search for extensions. Since the lookup table had not been initialized before, we can
      // assume there aren't any extensions in the modules we've already loaded.
      let extDecls = findExtensions(in: module)
      for decl in extDecls {
        memberLookupTable!.merge(extension: decl)
      }
    } else if memberLookupTable!.generationNumber < context.currentGeneration {
      // Update the lookup table with this module's extensions.
      let extDecls = findExtensions(in: module)
      for decl in extDecls {
        memberLookupTable!.merge(extension: decl)
      }
    }

    return memberLookupTable![memberName] ?? []
  }

}
