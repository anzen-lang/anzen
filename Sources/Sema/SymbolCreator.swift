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
public final class SymbolCreator: ASTVisitor {

  /// The AST context.
  public let context: ASTContext
  /// A stack of scopes used to determine in which one a new symbol should be created.
  private var scopes: Stack<Scope> = []
  /// A stack of generic placeholders declarations nested inside generic types should inherit.
  private var placeholders: Stack<[PlaceholderType]> = []
  /// The error symbol.
  private var errorSymbol: Symbol?
  /// Whether or not the built-in module is being visited.
  private var isVisitingBuiltin: Bool = false

  public init(context: ASTContext) {
    self.context = context
  }

  public func visit(_ node: ModuleDecl) throws {
    // Create a new scope for the module.
    node.innerScope = Scope(name: node.id?.qualifiedName, module: node)

    // Create the module's error symbol.
    errorSymbol = node.innerScope?.create(name: "<error>", type: ErrorType.get)

    // We need to set whether or not we're visiting the built-in module, so that built-in types can
    // be properly marked as such.
    isVisitingBuiltin = node.id == .builtin

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
    let attributes = node.attributes.contains(.reassignable)
      ? SymbolAttributes.reassignable
      : SymbolAttributes.none
    node.symbol = scope.create(name: node.name, type: TypeVariable(), attributes: attributes)
    try traverse(node)

    // Register the property's declaration.
    node.module.declarations[node.symbol!] = node
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

    switch node.kind {
    case .constructor, .destructor, .method:
      // If the function is a type member, we have to inject `self` into its inner scope.
      let typeScope = scope.parent!
      let selfTy = (typeScope.symbols["Self"]!.first!.type as! Metatype).type
      innerScope.create(name: "self", type: selfTy)

      switch node.kind {
      case .constructor:
        // Constructor types actually look like `A -> Self`, where `A` are the parameters of the
        // declared function.
        let ctorTy = context.getFunctionType(
          from: parameters,
          to: selfTy,
          placeholders: functionPlaceholders)
        node.symbol = scope.create(
          name: node.name, type: ctorTy, attributes: [.overloadable, .static, .method])

      case .method:
        // Method types actually look like `(_: Self) -> (A -> B)`, where `(A -> B)` is the type
        // of the declared function.
        let methTy = context.getFunctionType(
          from: [Parameter(type: selfTy)],
          to: context.getFunctionType(from: parameters, to: TypeVariable()),
          placeholders: functionPlaceholders)
        node.symbol = scope.create(
          name: node.name, type: methTy, attributes: [.overloadable, .method])

      case .destructor:
        // Destructor types actually look like `(_: Self) -> (() -> Nothing)`.
        assert(parameters.isEmpty)
        let dtorTy = context.getFunctionType(
          from: [Parameter(type: selfTy)],
          to: context.getFunctionType(from: [], to: NothingType.get))
        node.symbol = scope.create(
          name: node.name, type: dtorTy, attributes: .method)

      default:
        break
      }

    default:
      let fnTy = context.getFunctionType(
        from: parameters,
        to: TypeVariable(),
        placeholders: functionPlaceholders)
      node.symbol = scope.create(name: node.name, type: fnTy, attributes: .overloadable)
    }

    // Visit the function's body.
    if let body = node.body {
      try visit(body)
    }
    scopes.pop()

    // Register the function's declaration.
    node.module.declarations[node.symbol!] = node
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

    if isVisitingBuiltin {
      // Bind Anzen's `Anything` and `Nothing` to their respective singleton.
      if node.name == "Anything" {
        node.symbol!.type = AnythingType.get.metatype
        return
      } else if node.name == "Nothing" {
        node.symbol!.type = NothingType.get.metatype
        return
      }
    }

    let declaredType = context.getStructType(
      for: node, memberScope: node.body.innerScope!, isBuiltin: isVisitingBuiltin)
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
    let members = node.body.statements.compactMap({ ($0 as? NamedDecl)?.symbol })
    declaredType.members = members

    // Register the type's declaration.
    node.module.declarations[node.symbol!] = node
  }

  private func canBeDeclared(node: NamedDecl) -> Bool {
    let scope = scopes.top
    assert(scope != nil, "unscoped declaration")

    let symbols = scope!.symbols[node.name]
    if node is FunDecl {
      guard symbols?.all(satisfy: { $0.isOverloadable }) ?? true else {
        context.add(error: SAError.illegalRedeclaration(name: node.name), on: node)
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
