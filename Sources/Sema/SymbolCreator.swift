import AST
import Utils

/// A visitor that creates the scope and symbols of to be associated with the AST nodes.
///
/// This pass is responsible for three things:
/// * It annotates nodes delimiting scopes with the corresponding scope object.
/// * It annotates named declaration with scoped symbols that uniquely represent them.
/// * It creates the possibly type corresponding to nominal type and function declarations.
///
/// This pass must be ran before name binding can take place.
public struct SymbolCreator: ASTVisitor, SAPass {

  public init(context: ASTContext) {
    self.context = context
  }

  /// The AST context.
  public let context: ASTContext
  /// A stack of nodes that keeps track of which scope a new symbol should be created in.
  private var stack: Stack<ScopeDelimiter> = []
  /// The error.
  private var errorSymbol: Symbol?
  /// Whether or not the built-in module is being visited.
  private var isBuiltinVisited: Bool = false

  public mutating func visit(_ node: ModuleDecl) throws {
    // Create a new scope for the module.
    node.innerScope = Scope(name: node.id?.qualifiedName, module: node)

    if node.id == .builtin {
      node.innerScope?.create(name: "Anything", type: TypeBase.anything.metatype)
      node.innerScope?.create(name: "Nothing", type: TypeBase.nothing.metatype)
    }

    // Create the module's error symbol.
    errorSymbol = node.innerScope?.create(name: "<error>", type: ErrorType.get)

    // We need to set whether or not we're visiting the built-in module, so that built-in types can
    // be properly marked as such.
    isBuiltinVisited = node.id == .builtin

    // Visit the module's statements.
    stack.push(node)
    try visit(node.statements)
    stack.pop()

    // FIXME: Extensions that are visited before the type they extend should be revisited once
    // those symbols have been created.
  }

  public mutating func visit(_ node: Block) throws {
    // Create a new scope for the block.
    node.innerScope = Scope(parent: stack.top!.innerScope)

    // Visit the block's statements.
    stack.push(node)
    try visit(node.statements)
    stack.pop()
  }

  public mutating func visit(_ node: PropDecl) throws {
    // Make sure the property's name can be declared in the current scope.
    guard canBeDeclared(node: node) else {
      node.symbol = errorSymbol
      return
    }

    // Create a new symbol for the property, and visit the node's declaration.
    let scope = stack.top!.innerScope!
    node.symbol = scope.create(name: node.name, type: TypeVariable())
    try traverse(node)
  }

  public mutating func visit(_ node: FunDecl) throws {
    // Make sure the function's name can be declared in the current scope.
    guard canBeDeclared(node: node) else {
      node.symbol = errorSymbol
      return
    }

    // Create the inner scope of the function.
    let scope = stack.top!.innerScope!
    let innerScope = Scope(name: node.name, parent: scope)
    node.innerScope = innerScope

    // Visit the function's parameters.
    stack.push(node)
    try visit(node.parameters)

    // Create the symbols for the function, its placeholders and its parameters.
    let parameters = node.parameters.map {
      Parameter(label: $0.label, type: $0.type!)
    }
    var placeholders: [PlaceholderType] = []
    for name in node.placeholders {
      if innerScope.defines(name: name) {
        context.add(error: SAError.duplicateDeclaration(name: name), on: node)
        return
      }
      let symbol = innerScope.create(name: name, type: nil)
      let phType = context.getPlaceholderType(for: symbol)
      symbol.type = phType.metatype
      placeholders.append(phType)
    }
    let functionType = context.getFunctionType(
      from: parameters,
      to: TypeVariable(),
      placeholders: placeholders)
    node.symbol = scope.create(name: node.name, type: functionType, overloadable: true)

    // Visit the function's body.
    if let body = node.body {
      try visit(body)
    }
    stack.pop()
  }

  public mutating func visit(_ node: ParamDecl) throws {
    // Make sure the parameter's name can be declared in the current scope.
    guard canBeDeclared(node: node) else {
      node.symbol = errorSymbol
      return
    }

    // Create a new symbol for the parameter, and visit the node's declaration.
    let scope = stack.top!.innerScope!
    node.symbol = scope.create(name: node.name, type: TypeVariable())
    try traverse(node)
  }

  public mutating func visit(_ node: StructDecl) throws {
    // Make sure the struct's name can be declared in the current scope.
    guard canBeDeclared(node: node) else {
      node.symbol = errorSymbol
      return
    }

    // Create the inner scope of the struct.
    let scope = stack.top!.innerScope!
    let innerScope = Scope(name: node.name, parent: scope)
    node.innerScope = innerScope

    // Create the symbols for the struct and its placeholders.
    node.symbol = scope.create(name: node.name, type: nil)
    let declaredType = context.getStructType(for: node.symbol!)
    node.symbol!.type = declaredType.metatype
    for name in node.placeholders {
      if innerScope.defines(name: name) {
        context.add(error: SAError.duplicateDeclaration(name: name), on: node)
        return
      }
      let symbol = innerScope.create(name: name, type: nil)
      let phType = context.getPlaceholderType(for: symbol)
      symbol.type = phType.metatype
      declaredType.placeholders.append(phType)
    }

    innerScope.create(name: "Self", type: declaredType.metatype)

    // Visit the struct's members.
    stack.push(node)
    try traverse(node)
    stack.pop()

    // Create the body of the declared type.
    for member in node.body.statements {
      switch member {
      case let property as PropDecl:
        declaredType.members[property.name] = [property.type!]

      case let method as FunDecl:
        if declaredType.members[method.name] == nil {
          declaredType.members[method.name] = []
        }
        declaredType.members[method.name]!.append(method.type!)

      default:
        unreachable()
      }
    }
  }

  private func canBeDeclared(node: NamedDecl) -> Bool {
    let scope = stack.top?.innerScope
    assert(scope != nil, "unscoped declaration")

    let symbols = scope!.symbols[node.name]
    if node is FunDecl {
      guard symbols?.all(satisfy: { $0.overloadable }) ?? true else {
        context.add(error: SAError.invalidRedeclaration(name: node.name), on: node)
        return false
      }
    } else {
      guard symbols == nil else {
        context.add(error: SAError.duplicateDeclaration(name: node.name), on: node)
        return false
      }
    }
    return true
  }

}
