import AST
import Utils

public struct NameBinder: ASTVisitor, SAPass {

  public static let title = "Name binding"

  public init(context: ASTContext) {
    self.context = context
  }

  public mutating func visit(_ node: ModuleDecl) throws {
    // Don't implicitly import core symbols if the module describing them is being visited.
    if node.id != .builtin {
      scopes.push(context.builtinScope)
      if node.id != .stdlib {
        scopes.push(context.stdlibScope)
      }
    }

    // Note that all modules implicitly import Anzen's core modules so that symbols from those can
    // be referred without prefixing. This gets done by having the scopes of user modules descend
    // from that of Anzen's core libraries.
    node.innerScope!.parent = scopes.top

    scopes.push(node.innerScope!)
    try visit(node.statements)
    scopes.pop()
  }

  public mutating func visit(_ node: Block) throws {
    scopes.push(node.innerScope!)
    try visit(node.statements)
    scopes.pop()
  }

  public mutating func visit(_ node: PropDecl) throws {
    underDeclaration[node.scope!] = node.name
    try traverse(node)
    underDeclaration.removeValue(forKey: node.scope!)
  }

  public mutating func visit(_ node: FunDecl) throws {
    scopes.push(node.innerScope!)
    for param in node.parameters {
      underDeclaration[param.scope!] = param.name
      try visit(param)
    }
    underDeclaration.removeValue(forKey: node.innerScope!)
    if node.codomain != nil {
      try visit(node.codomain!)
    }
    if node.body != nil {
      try visit(node.body!)
    }
    scopes.pop()
  }

  public mutating func visit(_ node: StructDecl) throws {
    scopes.push(node.innerScope!)
    try visit(node.body)
    scopes.pop()
  }

  public mutating func visit(_ node: Ident) throws {
    // Find the scope that defines the visited identifier.
    guard let scope = scopes.top?.findScope(declaring: node.name) else {
      context.add(error: SAError.undefinedSymbol(name: node.name), on: node)
      return
    }

    // If we're visiting the initial value of the identifier's declaration (e.g. as part of a
    // property declaration), we should bind it to an enclosing scope.
    if underDeclaration[scope] == node.name {
      guard let parent = scope.parent?.findScope(declaring: node.name) else {
        context.add(error: SAError.undefinedSymbol(name: node.name), on: node)
        return
      }
      node.scope = parent
    } else {
      node.scope = scope
    }

    // Visit the specializations.
    for specialization in node.specializations {
      try visit(specialization.value)
    }
  }

  /// The AST context.
  public let context: ASTContext
  /// A stack of scope, used to bind symbols to their respective scope, lexically.
  private var scopes: Stack<Scope> = []

  /// Keeps track of what identifier is being declared while visiting its declaration.
  ///
  /// This mapping keeps track of the identifier being declared while visiting its declaration,
  /// which is necessary to properly map the scopes of declaration expressions that refer to the
  /// same name as the identifier under declaration, but from an enclosing scope. For instance:
  ///
  ///     let x = 0
  ///     fun f() { let x = x }
  ///
  private var underDeclaration: [Scope: String] = [:]

}