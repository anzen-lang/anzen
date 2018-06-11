import AST
import Utils

public final class ConstraintCreator: ASTVisitor, SAPass {

  public init(context: ASTContext) {
    self.context = context
  }

  /// The AST context.
  public let context: ASTContext

  public func visit(_ node: PropDecl) throws {
    var propType: TypeBase? = nil
    if let annotation = node.typeAnnotation {
      propType = typeFromAnnotation(annotation: annotation)
      context.add(constraint:
        .equality(t: node.type!, u: propType!, at: .location(node, .annotation)))
    }

    if let (_, value) = node.initialBinding {
      try visit(value)
      context.add(constraint:
        .conformance(t: value.type!, u: node.type!, at: .location(node, .rvalue)))
    }
  }

  public func visit(_ node: FunDecl) throws {
    // Determine the expected codomain of the function.
    let codomain: TypeBase
    if node.kind == .constructor {
      // If the function is a constructor, its return type must be `Self`.
      assert(node.codomain == nil)
      let selfSymbol = node.scope?.parent?.symbols["Self"]

      // Assuming constructor declarations outside of a type are caught during AST sanitizing, the
      // `Self` symbol can be expected to have been defined at this point.
      assert(selfSymbol != nil, "constructor not declared within a type")
      assert(selfSymbol?.count == 1, "overloaded 'Self' symbol")
      assert(selfSymbol![0].type is Metatype, "'Self' should be a metatype")
      codomain = (selfSymbol![0].type as! Metatype).type
    } else if node.codomain != nil {
      // The function has an explicit codomain annotation.
      codomain = typeFromAnnotation(annotation: node.codomain!)
    } else {
      // In the absence of explicit codomain annotation, use `Nothing`.
      codomain = TypeBase.nothing
    }

    let fnType = node.type as! FunctionType
    context.add(constraint:
      .equality(t: fnType.codomain, u: codomain, at: .location(node, .codomain)))

    try visit(node.parameters)
    if let body = node.body {
      try visit(body)
    }
  }

  public func visit(_ node: ParamDecl) throws {
    // Extract the type of the parameter from its annotation.
    var paramType: TypeBase? = nil
    if let annotation = node.typeAnnotation {
      paramType = typeFromAnnotation(annotation: annotation)
      context.add(constraint:
        .equality(t: node.type!, u: paramType!, at: .location(node, .annotation)))
    }

    if let value = node.defaultValue {
      try visit(value)
      context.add(constraint:
        .conformance(t: value.type!, u: node.type!, at: .location(node, .rvalue)))
    }
  }

  public func visit(_ node: BindingStmt) throws {
    try visit(node.lvalue)
    try visit(node.rvalue)
    context.add(constraint:
      .conformance(t: node.rvalue.type!, u: node.lvalue.type!, at: .location(node, .rvalue)))
  }

  public func visit(_ node: CallExpr) throws {
    // Build the supposed type of the callee. Note the use of fresh variables so as to loosen
    // the constraint on the arguments.
    let domain = node.arguments.map { Parameter(label: $0.label, type: TypeVariable()) }
    node.type = TypeVariable()
    let fnType = context.getFunctionType(from: domain, to: node.type!)

    try visit(node.callee)
    context.add(constraint:
      .equality(t: fnType, u: node.callee.type!, at: .location(node, .call)))

    // Create conformance constraints for the arguments.
    let location: ConstraintLocation = .location(node, .call)
    for (i, (argument, parameter)) in zip(node.arguments, fnType.domain).enumerated() {
      try visit(argument)
      context.add(constraint:
        .conformance(t: argument.type!, u: parameter.type, at: location + .parameter(i)))
    }

    // FIXME: Create a disjunction with a construction constraint?
  }

  public func visit(_ node: CallArg) throws {
    try visit(node.value)
    node.type = node.value.type
  }

  public func visit(_ node: SelectExpr) throws {
    // We use a fresh variable for the node's ownee, which will be used to build  a membership
    // constraint with the inferred type of the owner.
    node.ownee.type = TypeVariable()
    node.type = node.ownee.type

    let ownerType: TypeBase
    if let owner = node.owner {
      try visit(owner)
      ownerType = owner.type!
    } else {
      // If the select doesn't have an explicit owner, then the type of the implicit one must be the
      // metatype of that of of the ownee. In other words, `member` should be static.
      // FIXME: Does this work, knowing that `node.type` is a type variable?
      ownerType = node.type!.metatype
    }
    context.add(constraint:
      .member(t: ownerType, member: node.ownee.name, u: node.type!, at: .location(node, .select)))
  }

  public func visit(_ node: Ident) throws {
    node.type = TypeVariable()

    // FIXME: Handle explicit generic parameters.

    // Retrieve the symbol(s) associated with the identifier. If there're more than one, create a
    // disjunction constraint to model the different choices.
    let symbols = node.scope!.symbols[node.name] ?? []
    assert(!symbols.isEmpty)
    let choices: [Constraint] = symbols.map {
      .equality(t: node.type!, u: $0.type!, at: .location(node, .identifier))
    }
    if choices.count == 1 {
      context.add(constraint: choices[0])
    } else {
      context.add(constraint: .disjunction(choices, at: .location(node, .identifier)))
    }
  }

  public func visit(_ node: Literal<Bool>) throws {
    node.type = context.builtinTypes["Bool"]
    assert(node.type != nil)
  }

  public func visit(_ node: Literal<Int>) throws {
    node.type = context.builtinTypes["Int"]
    assert(node.type != nil)
  }

  public func visit(_ node: Literal<Float>) throws {
    node.type = context.builtinTypes["Float"]
    assert(node.type != nil)
  }

  public func visit(_ node: Literal<String>) throws {
    node.type = context.builtinTypes["String"]
    assert(node.type != nil)
  }

  private func typeFromAnnotation(annotation: Node) -> TypeBase {
    switch annotation {
    case let sign as QualSign:
      return sign.signature.map { typeFromAnnotation(annotation: $0) } ?? TypeVariable()

    case let ident as Ident:
      guard let symbols = ident.scope?.symbols[ident.name] else {
        // The symbols of an identifier couldn't be linked; we use an error type.
        return ErrorType.get
      }

      // When the annotation is an identifier, it should be associated with a unique symbol that
      // must be typed with a metatype.
      guard
        symbols.count == 1,
        let meta = symbols[0].type as? Metatype,
        let type = meta.type as? NominalType else
      {
        context.add(error: SAError.invalidTypeIdentifier(name: ident.name), on: ident)
        return ErrorType.get
      }
      ident.type = type.metatype
      return type

    default:
      unreachable()
    }
  }

}
