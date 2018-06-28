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
public final class SymbolCreator: ASTVisitor, SAPass {

  public init(context: ASTContext) {
    self.context = context
  }

  /// The AST context.
  public let context: ASTContext
  /// A stack of scopes used to determine in which one a new symbol should be created.
  private var scopes: Stack<Scope> = []
  /// A stack of generic placeholders declarations nested inside generic types should inherit.
  private var placeholders: Stack<[PlaceholderType]> = []

  /// The error symbol.
  private var errorSymbol: Symbol?
  /// Whether or not the built-in module is being visited.
  private var isBuiltinVisited: Bool = false

  public func visit(_ node: ModuleDecl) throws {
    // Create a new scope for the module.
    node.innerScope = Scope(name: node.id?.qualifiedName, module: node)

    // Create the module's error symbol.
    errorSymbol = node.innerScope?.create(name: "<error>", type: ErrorType.get)

    // We need to set whether or not we're visiting the built-in module, so that built-in types can
    // be properly marked as such.
    isBuiltinVisited = node.id == .builtin

    // Visit the module's statements.
    scopes.push(node.innerScope!)
    try visit(node.statements)
    scopes.pop()

    // FIXME: Extensions that are visited before the type they extend should be revisited once
    // those symbols have been created.
  }

  public func visit(_ node: Block) throws {
    // Create a new scope for the block.
    node.innerScope = Scope(name: "block", parent: scopes.top!)

    // Visit the block's statements.
    scopes.push(node.innerScope!)
    try visit(node.statements)
    scopes.pop()
  }

  public func visit(_ node: PropDecl) throws {
    // Make sure the property's name can be declared in the current scope.
    guard canBeDeclared(node: node) else {
      node.symbol = errorSymbol
      return
    }

    // Create a new symbol for the property, and visit the node's declaration.
    let scope = scopes.top!
    node.symbol = scope.create(name: node.name, type: TypeVariable())
    try traverse(node)
  }

  public func visit(_ node: FunDecl) throws {
    // Make sure the function's name can be declared in the current scope.
    guard canBeDeclared(node: node) else {
      node.symbol = errorSymbol
      return
    }

    // Create the inner scope of the function.
    let scope = scopes.top!
    let innerScope = Scope(name: node.name, parent: scope)
    node.innerScope = innerScope

    // Visit the function's parameters.
    scopes.push(innerScope)
    try visit(node.parameters)

    // Create the symbols for the function, its placeholders and its parameters.
    let parameters = node.parameters.map {
      Parameter(label: $0.label, type: $0.type!)
    }
    var functionPlaceholders: [PlaceholderType] = []
    for name in node.placeholders {
      if innerScope.defines(name: name) {
        context.add(error: SAError.duplicateDeclaration(name: name), on: node)
        return
      }
      let symbol = innerScope.create(name: name, type: nil)
      let phType = context.getPlaceholderType(for: symbol)
      symbol.type = phType.metatype
      functionPlaceholders.append(phType)
    }

    // Pass on generic placeholders from the enclosing generic types, if any.
    let inheritedPlaceholders = placeholders.top?.filter({ ph in
      !functionPlaceholders.contains(where: { $0.name == ph.name })
    }) ?? []
    functionPlaceholders.insert(contentsOf: inheritedPlaceholders, at: 0)

    let functionType = context.getFunctionType(
      from: parameters,
      to: TypeVariable(),
      placeholders: functionPlaceholders)
    node.symbol = scope.create(name: node.name, type: functionType, overloadable: true)

    // Visit the function's body.
    if let body = node.body {
      try visit(body)
    }
    scopes.pop()
  }

  public func visit(_ node: ParamDecl) throws {
    // Make sure the parameter's name can be declared in the current scope.
    guard canBeDeclared(node: node) else {
      node.symbol = errorSymbol
      return
    }

    // Create a new symbol for the parameter, and visit the node's declaration.
    let scope = scopes.top!
    node.symbol = scope.create(name: node.name, type: TypeVariable())
    try traverse(node)
  }

  public func visit(_ node: StructDecl) throws {
    // Make sure the struct's name can be declared in the current scope.
    guard canBeDeclared(node: node) else {
      node.symbol = errorSymbol
      return
    }

    // Create the inner scopes of the struct.
    let scope = scopes.top!
    let innerScope = Scope(name: node.name, parent: scope)
    node.innerScope = innerScope
    node.body.innerScope = Scope(name: "block", parent: node.innerScope)

    // Create the symbols for the struct and its placeholders.
    node.symbol = scope.create(name: node.name, type: nil)

    if isBuiltinVisited {
      // Bind Anzen's `Anything` and `Nothing` to their respective singleton.
      if node.name == "Anything" {
        node.symbol!.type = AnythingType.get.metatype
        return
      } else if node.name == "Nothing" {
        node.symbol!.type = NothingType.get.metatype
        return
      }
    }

    let declaredType = context.getStructType(for: node.symbol!, memberScope: node.body.innerScope!)
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

    // Pass on generic placeholders from the enclosing generic types, if any.
    let inheritedPlaceholders = placeholders.top?.filter({ ph in
      !declaredType.placeholders.contains(where: { $0.name == ph.name })
    }) ?? []
    declaredType.placeholders.insert(contentsOf: inheritedPlaceholders, at: 0)

    // Introduce `Self` in the scope.
    if declaredType.placeholders.isEmpty {
      innerScope.create(name: "Self", type: declaredType.metatype)
    } else {
      // If `Self` is generic, we must bound it to the placeholders of the method. Note that they
      // should necesarily include those of `Self`, as the method should have inherited them
      // during symbol creation.
      let bindings = Dictionary(uniqueKeysWithValues: declaredType.placeholders.map({ ($0, $0) }))
      let selfType = BoundGenericType(unboundType: declaredType, bindings: bindings)
      innerScope.create(name: "Self", type: selfType.metatype)
    }

    // Visit the struct's members.
    placeholders.push(declaredType.placeholders)
    scopes.push(innerScope)
    scopes.push(node.body.innerScope!)

    for statement in node.body.statements {
      try visit(statement)
    }

    scopes.pop()
    scopes.pop()
    placeholders.pop()

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
    let scope = scopes.top
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
