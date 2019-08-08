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
      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

    func visit(_ node: StructDecl) {
      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

    func visit(_ node: UnionDecl) {
      inDeclContext(node) {
        node.traverse(with: self)
      }
    }

    func visit(_ node: TypeExtDecl) {
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
      let decls = currentDeclContext.lookup(unqualifiedName: node.name, inCompilerContext: context)
      if decls.isEmpty {
        node.registerError(message: Issue.unboundIdentifier(name: node.name))
      } else {
        node.referredDecls = decls
      }

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
      let decls = currentDeclContext.lookup(unqualifiedName: node.name, inCompilerContext: context)
      if decls.isEmpty {
        node.registerError(message: Issue.unboundIdentifier(name: node.name))
      } else if !decls[0].isTypeDecl {
        node.registerError(message: Issue.invalidTypeIdentifier(name: node.name))
      } else {
        assert(decls.count == 1, "bad extension on overloaded type name")
        node.referredDecl = decls[0]
      }

      node.traverse(with: self)
    }

    // MARK: Helpers

    private func inDeclContext(_ declContext: DeclContext, run block: () -> Void) {
      let previousDeclContext = currentDeclContext
      currentDeclContext = declContext
      block()
      currentDeclContext = previousDeclContext
    }

  }

}

// MARK: - Identifier lookup

extension DeclContext {

  func lookup(qualifiedTypeName: NestedIdentSign, inCompilerContext context: CompilerContext)
    -> NamedDecl?
  {
    switch qualifiedTypeName.owner {
    case let ident as IdentSign:
      // Look up the owner's declaration.
      var ownerDecl: NamedDecl
      if ident.referredDecl != nil {
        ownerDecl = ident.referredDecl!
      } else {
        let decls = lookup(unqualifiedName: ident.name, inCompilerContext: context)
        if decls.isEmpty {
          ident.registerError(message: Issue.unboundIdentifier(name: ident.name))
          return nil
        } else if !decls[0].isTypeDecl {
          ident.registerError(message: Issue.invalidTypeIdentifier(name: ident.name))
          return nil
        }

        assert(decls.count == 1, "bad overloaded type name")
        ownerDecl = decls[0]
      }

      // Look up the ownee in the owner's context.
      let ownee = qualifiedTypeName.ownee
      switch ownerDecl {
      case let nominalTypeDecl as NominalTypeDecl:
        let decls = nominalTypeDecl.lookup(memberName: ownee.name, inCompilerContext: context)
        if decls.isEmpty {
          ownee.registerError(
            message: Issue.nonExistingNestedType(ownerDecl: ownerDecl, owneeName: ownee.name))
          return nil
        } else if !decls[0].isTypeDecl {
          ownee.registerError(message: Issue.invalidTypeIdentifier(name: ownee.name))
          return nil
        }

        assert(decls.count == 1, "bad overloaded type name")
        return decls[0]

      case is BuiltinType:
        ownee.registerError(
          message: Issue.nonExistingNestedType(ownerDecl: ownerDecl, owneeName: ownee.name))
        return nil

      default:
        fatalError("bad owner in nested type signature")
      }

    default:
      fatalError("bad owner in nested type signature")
    }
  }

  /// Search for a declaration that matches the given unqualified identifier that is visible from
  /// this declaration context.
  ///
  /// This method may produce multiple results in cased the given identifier refers to overloaded
  /// declarations (i.e. function definitions). In this case, declarations are returned from the
  /// closest to the farthest context.
  func lookup(unqualifiedName: String, inCompilerContext context: CompilerContext) -> [NamedDecl] {
    var currentContext: DeclContext? = self
    var matches: [NamedDecl] = []

    while currentContext != nil {
      // In all cases, look in the current declaration context.
      let newMatches = currentContext!.allDecls(named: unqualifiedName)
      if !newMatches.isEmpty {
        if newMatches[0].isOverloadable {
          matches.append(contentsOf: newMatches)
        } else if matches.isEmpty {
          return newMatches
        } else {
          return matches
        }
      }

      // Handle nominal type declarations.
      if let nominalTypeDecl = currentContext as? NominalTypeDecl {
        // `Self` in a nominal type always refers to the type itself.
        if unqualifiedName == "Self" {
          assert(matches.isEmpty, "'Self' should not be overloaded")
          return [nominalTypeDecl]
        }

        // Search in the member and its extensions.
        let memberMatches = nominalTypeDecl
          .lookup(memberName: unqualifiedName, inCompilerContext: context)
        if !memberMatches.isEmpty {
          if memberMatches[0].isOverloadable {
            matches.append(contentsOf: memberMatches)
          } else if matches.isEmpty {
            return memberMatches
          } else {
            return matches
          }
        }

        // FIXME: Search in implemented interfaces.

        // If the type is nested in another type, continue the lookup in its enclosing context.
        if currentContext?.parent?.parent is NominalTypeDecl {
          currentContext = currentContext?.parent?.parent
          continue
        }

        // Continue the lookup at the module level.
        currentContext = nominalTypeDecl.module
        continue
      }

      // Handle extension declarations.
      if let extDecl = currentContext as? TypeExtDecl {
        if let extendedDecl = extDecl.resolveExtendedTypeDecl(inCompilerContext: context) {
          switch extendedDecl {
          case let declContext as DeclContext:
            // Continue the lookup in the extended declaration.
            currentContext = declContext
            continue

          case is BuiltinTypeDecl:
            // `Self` in a nominal type always refers to the type itself.
            if unqualifiedName == "Self" {
              assert(matches.isEmpty, "'Self' should not be overloaded")
              return [extendedDecl]
            }

            // FIXME: Search in built-in type extensions.
            currentContext = nil
            continue

          default:
            assertionFailure("bad extended declaration")
            break
          }
        }
      }

      // Walk outward declaration contexts to find overloaded symbols.
      assert(matches.isEmpty || matches[0].isOverloadable)
      currentContext = currentContext!.parent
    }

    // If no match could be bound, search in built-in types.
    if matches.isEmpty && CompilerContext.builtinTypeNames.contains(unqualifiedName) {
      return [context.builtinModule.firstDecl(named: unqualifiedName)!]
    } else {
      // Should we ensure uniqueness of each result?
      return matches
    }
  }

}

extension NamedDecl {

  var isTypeDecl: Bool {
    return (self is NominalTypeDecl)
        || (self is GenericParamDecl)
        || (self is BuiltinTypeDecl)
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
      // The type isn't nested, so we can look up its name directly.
      return searchModule.decls.compactMap { decl in
        ((decl as? TypeExtDecl)?.extType as? IdentSign)?.name == qName[0] ? decl : nil
      } as! [TypeExtDecl]
    } else {
      var extDecls: [TypeExtDecl] = []
      // The type is nested, so we need to match its qualified name with a nested type signature.
      for extDecl in searchModule.decls
        where (extDecl as? TypeExtDecl)?.extType is NestedIdentSign
      {
        var sign = (extDecl as! TypeExtDecl).extType
        var i = 0
        while let nestedIdent = sign as? NestedIdentSign {
          guard nestedIdent.ownee.name == qName[i]
            else { break }
          sign = nestedIdent.owner
          i += 1
        }
        if let ident = sign as? IdentSign, (ident.name == qName[i]) {
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
      // Create the lookup table.
      memberLookupTable = MemberLookupTable(generationNumber: context.currentGeneration)

      // Insert members defined in the context of the declaration's header.
      for member in decls where member is NamedDecl {
        memberLookupTable!.insert(member: member as! NamedDecl)
      }

      // Insert members in the context of the declaration's body.
      if let body = body as? BraceStmt {
        for member in body.decls where member is NamedDecl {
          memberLookupTable!.insert(member: member as! NamedDecl)
        }
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

extension TypeExtDecl {

  func resolveExtendedTypeDecl(inCompilerContext context: CompilerContext) -> NamedDecl? {
    switch extType {
    case let ident as IdentSign:
      if ident.referredDecl != nil {
        return ident.referredDecl!
      } else {
        let decls = module.lookup(unqualifiedName: ident.name, inCompilerContext: context)
        if decls.isEmpty {
          ident.registerError(message: Issue.unboundIdentifier(name: ident.name))
          return nil
        } else if !decls[0].isTypeDecl {
          ident.registerError(message: Issue.invalidTypeIdentifier(name: ident.name))
          return nil
        }

        ident.referredDecl = decls[0]
        return decls[0]
      }

    case let nestedIdent as NestedIdentSign:
      return module.lookup(qualifiedTypeName: nestedIdent, inCompilerContext: context)

    default:
      fatalError("bad extension")
    }
  }

}
