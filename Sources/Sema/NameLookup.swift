/// This file implements most of the code involved in name lookups as extensions on AST nodes.
///
/// Name lookups are performed by walking declaration contexts and searching for the appropriate
/// named declarations. Contexts are walked outward from an innermost "base" context until either
/// all looked up declarations are found, or a type or module context has been reached. As types
/// cannot capture local symbols, type declarations contexts represent boundaries at which lookups
/// moving outward. However, the search may continue in type extensions and implemented interfaces.
///
/// There are two kinds of lookups: unqualified and qualified. Unqualified lookups serve to resolve
/// plain identifiers, whereas qualified lookups serve to resolve explicit member selections and
/// nested type signatures.

import AST

extension DeclContext {

  /// Looks up declarations that match the given unqualified name, in all visible contexts.
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
      if let nominalTypeDecl = currentContext as? NominalOrBuiltinTypeDecl {
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
        if currentContext?.parent?.parent is NominalOrBuiltinTypeDecl {
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
    if matches.isEmpty && CompilerContext.BuiltinTypeName.contains(unqualifiedName) {
      return [context.builtinModule.firstDecl(named: unqualifiedName)!]
    } else {
      // Should we ensure uniqueness of each result?
      return matches
    }
  }

  /// Looks up the declaration that match the given qualified type name, in all visible contexts.
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
        } else if !(decls[0] is TypeDecl) {
          ident.registerError(message: Issue.invalidTypeIdentifier(name: ident.name))
          return nil
        }

        assert(decls.count == 1, "bad overloaded type name")
        ownerDecl = decls[0]
      }

      // Look up the ownee in the owner's context.
      let ownee = qualifiedTypeName.ownee
      switch ownerDecl {
      case let nominalTypeDecl as NominalOrBuiltinTypeDecl:
        let decls = nominalTypeDecl.lookup(memberName: ownee.name, inCompilerContext: context)
        if decls.isEmpty {
          ownee.registerError(
            message: Issue.nonExistingNestedType(ownerDecl: ownerDecl, owneeName: ownee.name))
          return nil
        } else if !(decls[0] is TypeDecl) {
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

}

extension NominalOrBuiltinTypeDecl {

  /// Finds all extensions of this type declaration in the given module.
  func findExtensions(in searchModule: Module) -> [TypeExtDecl] {
    // Compute this type's qualified name components.
    var parentContext = declContext!
    var nameComponents = [name]
    while parentContext.parent != nil {
      if let nominalTypeDecl = (parentContext as? BraceStmt)?.parent as? NominalOrBuiltinTypeDecl {
        nameComponents.append(nominalTypeDecl.name)
        parentContext = nominalTypeDecl.parent!
      } else {
        // The nominal type is nested in a non-type context, so it can't be extended.
        return []
      }
    }
    assert(parentContext === module)

    // Search for all extensions.
    var extDecls: [TypeExtDecl] = []
    if nameComponents.count == 1 {
      // The type isn't nested, so we can look up its name directly.
      for decl in searchModule.decls {
        if let extDecl = decl as? TypeExtDecl,
          let sign = extDecl.extTypeSign as? IdentSign,
          nameComponents[0] == sign.name
        {
          extDecls.append(extDecl)
        }
      }
    } else {
      // The type is nested, so we need to match its qualified name with a nested type signature.
      for decl in searchModule.decls {
        if let extDecl = decl as? TypeExtDecl,
          let sign = extDecl.extTypeSign as? NestedIdentSign,
          nameComponents == sign.qualifiedName
        {
          extDecls.append(extDecl)
        }
      }
    }

    return extDecls
  }

  /// Searches for a member declarations that matches the given unqualified identifier.
  ///
  /// This method may produce multiple results in cased the given identifier refers to overloaded
  /// declarations (i.e. function definitions). In this case, declarations are returned from the
  /// innermost to the outermost contexts.
  func lookup(memberName: String, inCompilerContext context: CompilerContext) -> [NamedDecl] {
    // Initialize the member lookup table as required.
    if memberLookupTable == nil {
      // Create the lookup table.
      memberLookupTable = MemberLookupTable(generationNumber: 0)

      // Insert members defined in the context of the declaration's header.
      for member in decls where member is NamedDecl {
        memberLookupTable!.insert(member: member as! NamedDecl)
      }

      // Insert members in the context of the declaration's body.
      if body != nil {
        for member in body!.decls where member is NamedDecl {
          memberLookupTable!.insert(member: member as! NamedDecl)
        }
      }
    }

    // Update the lookup table with this module's extensions.
    if memberLookupTable!.generationNumber < context.currentGeneration {
      for searchModule in context.modules.values
        where searchModule.generationNumber > memberLookupTable!.generationNumber
      {
        let extDecls = findExtensions(in: searchModule)
        for decl in extDecls {
          memberLookupTable!.merge(extension: decl)
        }
      }
    }

    return memberLookupTable![memberName] ?? []
  }

}

extension TypeExtDecl {

  /// Resolves the extended type's declaration node.
  func resolveExtendedTypeDecl(inCompilerContext context: CompilerContext) -> NamedDecl? {
    switch extTypeSign {
    case let ident as IdentSign:
      if ident.referredDecl != nil {
        return ident.referredDecl!
      } else {
        let decls = module.lookup(unqualifiedName: ident.name, inCompilerContext: context)
        if decls.isEmpty {
          ident.registerError(message: Issue.unboundIdentifier(name: ident.name))
          return nil
        } else if !(decls[0] is TypeDecl) {
          ident.registerError(message: Issue.invalidTypeIdentifier(name: ident.name))
          return nil
        }

        ident.referredDecl = (decls[0] as! (TypeDecl & NamedDecl))
        return decls[0]
      }

    case let nestedIdent as NestedIdentSign:
      return module.lookup(qualifiedTypeName: nestedIdent, inCompilerContext: context)

    default:
      fatalError("bad extension")
    }
  }

}

extension NestedIdentSign {

  /// The relative qualified name represented by this signature.
  ///
  /// Qualified name are represented by array of name components, starting from the innermost one.
  /// For instance, the signature `Foo::Bar::Baz` is represented by the components
  /// `["Baz", "Bar", "Foo"]`.
  ///
  /// If the root signature is implicit, the last component is a single dot. For instance
  /// `::Bar::Baz` is represented by the components `["Baz", "Bar", "."]`.
  var qualifiedName: [String] {
    var components = [ownee.name]
    var sign: TypeSign = owner
    while let nestedIdent = sign as? NestedIdentSign {
      components.append(nestedIdent.ownee.name)
      sign = nestedIdent.owner
    }

    if let ident = sign as? IdentSign {
      components.append(ident.name)
    } else if let implictNestedIdent = sign as? ImplicitNestedIdentSign {
      components.append(implictNestedIdent.ownee.name)
      components.append(".")
    } else {
      assertionFailure("bad owner in nested type signature")
    }

    return components
  }

}
