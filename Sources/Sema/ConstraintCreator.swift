import AST
import Utils

public struct ConstraintCreator: ASTVisitor, SAPass {

  public static let title = "Constraint creation"

  public init(context: ASTContext) {
    self.context = context
  }

  /// The AST context.
  public let context: ASTContext

  public mutating func visit(_ node: PropDecl) throws {
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

  public mutating func visit(_ node: FunDecl) throws {
    let fnType = node.type as! FunctionType
    let codomain: TypeBase
    if node.codomain != nil {
      codomain = typeFromAnnotation(annotation: node.codomain!)
    } else {
      codomain = TypeBase.nothing
    }
    context.add(constraint:
      .equality(t: fnType.codomain, u: codomain, at: .location(node, .codomain)))

    try visit(node.parameters)
    if let body = node.body {
      try visit(body)
    }
  }

  public mutating func visit(_ node: ParamDecl) throws {
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

  public mutating func visit(_ node: BindingStmt) throws {
    try visit(node.lvalue)
    try visit(node.rvalue)
    context.add(constraint:
      .conformance(t: node.rvalue.type!, u: node.lvalue.type!, at: .location(node, .rvalue)))
  }

  public mutating func visit(_ node: CallExpr) throws {
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

    // FIXME: By directly using the type of the parameters to build the function type, we constrain
    // the type of the function (i.e.) to be an exact match with the argument list. This will
    // prevent polymorphic functions to properly compute the join of their arguments, e.g.:
    //
    //     fun poly<T>(x: T, y: T) -> T { ... }
    //     let a = poly(x = 0, y = true)
    //
    // Using conformance rather than equality would relax this constrain, but make any polymorphic
    // function compatible with the callee (module the lenght and labels of their domain), as one
    // could always eventually solve `(x: A) -> B ≤ (x: Anything) -> Anything`.
    //
    // A better way to tackle this issue might be to create the function type with fresh variables
    // for its parameters, on which a conformance constraint would bind them to the arguments. In
    // other words, the same way the codomain is handled.

    // FIXME: Create a disjunction with a construction constraint?
  }

  public mutating func visit(_ node: CallArg) throws {
    try visit(node.value)
    node.type = node.value.type
  }

  public mutating func visit(_ node: Ident) throws {
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
