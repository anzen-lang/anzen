import AST
import Utils

public final class NameBinder: ASTVisitor {

  /// The AST context.
  public let context: ASTContext
  /// A stack of scope, used to bind symbols to their respective scope, lexically.
  private var scopes: Stack<Scope> = []

  /// A mapping keeping track of what identifier is being declared while visiting its declaration.
  ///
  /// This mapping keeps track of the identifier being declared while visiting its declaration,
  /// which is necessary to properly map the scopes of declaration expressions that refer to the
  /// same name as the identifier under declaration, but from an enclosing scope. For instance:
  ///
  ///     let x = 0
  ///     fun f() { let x = x }
  ///
  private var underDeclaration: [Scope: String] = [:]

  public init(context: ASTContext) {
    self.context = context
  }

  public func visit(_ node: ModuleDecl) {
    // Note that user modules implicitly import Anzen's core modules so that symbols from those can
    // be referred without prefixing. Hence, unless those modules are being visited, their scopes
    // are added to the scope stack so that name binding can succeed.
    if node.id != .builtin {
      guard let builtin = context.loadedModules[.builtin]?.innerScope else {
        fatalError("built-in module not loaded")
      }
      scopes.push(builtin)

      if node.id != .stdlib {
        guard let stdlib = context.loadedModules[.stdlib]?.innerScope else {
          fatalError("stdlib module not loaded")
        }
        scopes.push(stdlib)
      }
    }

    scopes.push(node.innerScope!)
    visit(node.statements)
    scopes.pop()
  }

  public func visit(_ node: Block) {
    scopes.push(node.innerScope!)
    visit(node.statements)
    scopes.pop()
  }

  public func visit(_ node: PropDecl) {
    underDeclaration[node.scope!] = node.name
    traverse(node)
    underDeclaration.removeValue(forKey: node.scope!)
  }

  public func visit(_ node: FunDecl) {
    scopes.push(node.innerScope!)
    for param in node.parameters {
      underDeclaration[param.scope!] = param.name
      visit(param)
    }
    underDeclaration.removeValue(forKey: node.innerScope!)
    if node.codomain != nil {
      visit(node.codomain!)
    }
    if node.body != nil {
      visit(node.body!)
    }
    scopes.pop()
  }

  public func visit(_ node: StructDecl) {
    scopes.push(node.innerScope!)
    visit(node.body)
    scopes.pop()
  }

  public func visit(_ node: TypeIdent) {
    // Find the scope that defines the visited identifier.
    guard let scope = findScope(declaring: node.name) else {
      context.add(error: SAError.undefinedSymbol(name: node.name), on: node)
      return
    }

    // Type identifiers can't be overloaded.
    guard scope.symbols[node.name]?.count == 1 else {
      context.add(error: SAError.invalidTypeIdentifier(name: node.name), on: node)
      return
    }
    node.symbol = scope.symbols[node.name]!.first!

    // Visit the specializations.
    for specialization in node.specializations {
      visit(specialization.value)
    }
  }

  public func visit(_ node: SelectExpr) {
    // Only visit the owner (if any), as the scope of the ownee has yet to be inferred.
    if let owner = node.owner {
      visit(owner)
    }
  }

  public func visit(_ node: Ident) {
    // Find the scope that defines the visited identifier.
    guard let scope = findScope(declaring: node.name) else {
      context.add(error: SAError.undefinedSymbol(name: node.name), on: node)
      return
    }
    node.scope = scope

    // Visit the specializations.
    for specialization in node.specializations {
      visit(specialization.value)
    }
  }

  private func findScope(declaring name: String) -> Scope? {
    let candidates = scopes
    guard let index = candidates.firstIndex(where: { $0.symbols[name] != nil })
      else { return nil }

    if underDeclaration[scopes[index]] == name {
      // If we're visiting the initial value of the identifier's declaration , we should bind it to
      // an enclosing scope.
      return candidates.dropFirst(index + 1).first { $0.symbols[name] != nil }
    } else {
      return scopes[index]
    }
  }

}
