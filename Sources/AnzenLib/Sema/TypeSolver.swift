import SwiftProductGenerator

/// Infer the type annotations of a module AST.
public func inferTypes(_ module: ModuleDecl) throws {
    var pass0 = NominalTypeFinder()
    try pass0.visit(module)

    let environment = Substitution()

    var pass1 = DeclarationTypeCreator(environment: environment)
    try pass1.visit(module)
    var pass2 = TypeSolver(environment: environment)
    try pass2.visit(module)
    var pass3 = TypeReifier(environment: environment)
    try pass3.visit(module)
}

/// Identify symbols representing nominal types.
///
/// This visitor doesn't create actual types yet. It only associates symbols representing types to
/// instances of TypeName or TypePlaceholder, so that we can interpret type annotations later on.
struct NominalTypeFinder: ASTVisitor {

    mutating func visit(_ node: StructDecl) throws {
        node.type = QualifiedType(
            type: TypeFactory.makeName(name: node.name, type: TypeVariable()))
        assert(node.scope![node.name].count == 1)
        node.scope![node.name][0].type = node.type

        // Bind the `Self` placeholder.
        assert(node.innerScope!["Self"].count == 1)
        node.innerScope!["Self"][0].type = node.type

        try self.visit(node.body)
    }

    mutating func visit(_ node: FunDecl) throws {
        for placeholderName in node.placeholders {
            node.innerScope![placeholderName].first?.type = QualifiedType(
                type: TypePlaceholder(named: placeholderName))
        }
        try self.traverse(node)
    }

}

/// Build the type of symbol declarations.
///
/// Note that this visitor requires symbols representing nominal types to have been identified
/// (see `NominalTypeFinder`).
struct DeclarationTypeCreator: ASTVisitor {

    mutating func visit(_ node: FunDecl) throws {
        // Extract the function's domain.
        var domain: [(label: String?, type: QualifiedType)] = []
        for parameter in node.parameters {
            try self.visit(parameter)
            domain.append((parameter.label, parameter.type!))
        }

        // The codomain is either a signature we've to read, or `Nothing`.
        var codomain: QualifiedType
        if node.codomain != nil {
            codomain = try analyzeTypeAnnotation(node.codomain!)
            if let union = codomain.unqualified as? TypeUnion {
                codomain = mostRestrictiveVariants(of: union)
            }
        } else {
            codomain = QualifiedType(
                type       : BuiltinScope.AnzenNothing,
                qualifiedBy: [.cst, .stk, .val])
        }

        // Once we've computed the domain and codomain of the function's signature, we can create
        // a type for the function itself. Since functions emitted as shared reference, we declare
        // them with `@mut @shd @ref`.
        node.type = QualifiedType(
            type: TypeFactory.makeFunction(
                placeholders: Set(node.placeholders),
                domain      : domain,
                codomain    : codomain),
            qualifiedBy: [.mut, .shd, .ref])

        // Visit the body of the function.
        try self.visit(node.body)

        // Set the symbol's type.
        for symbol in node.scope![node.name] {
            if symbol.node === node {
                symbol.type = node.type
                break
            }
        }
    }

    mutating func visit(_ node: ParamDecl) throws {
        // Extract the type of the parameter.
        node.type = try analyzeTypeAnnotation(node.typeAnnotation)
        if let union = node.type!.unqualified as? TypeUnion {
            node.type = mostRestrictiveVariants(of: union)
        }

        // Set the symbol's type.
        assert(node.scope![node.name].count == 1)
        node.scope![node.name][0].type = node.type
    }

    /// Extract the type of the property from its annotation if it is defined, or use a fresh
    /// variable otherwise.
    ///
    /// Note that if the property is declared with an initial value bound by reference (i.e. with
    /// `&-`), we keep the most restrictive `@ref` variant rather than the `@val`. This lets us
    /// write declarations such as
    ///
    ///     let x &- y
    ///
    /// without the need to explicitly qualify `x` with `@ref`. Other qualifiers are are inferred
    /// with the usual rule.
    mutating func visit(_ node: PropDecl) throws {
        if let typeAnnotation = node.typeAnnotation {
            node.type = try analyzeTypeAnnotation(typeAnnotation)
        } else {
            node.type = TypeFactory.makeVariants(of: TypeVariable())
        }

        if let union = node.type!.unqualified as? TypeUnion,
           let (bindingOp, _) = node.initialBinding
        {
            let expected = bindingOp == Operator.ref
                ? TypeQualifier.ref
                : TypeQualifier.val

            for qualifiers in TypeQualifier.combinations.filter({ $0.contains(expected) }) {
                if let type = union.first(where: { $0.qualifiers == qualifiers }) {
                    node.type = type
                    break
                }
            }
        }

        // Set the symbol's type.
        assert(node.scope![node.name].count == 1)
        node.scope![node.name][0].type = node.type
    }

    public mutating func visit(_ node: StructDecl) throws {
        // Build the types of the struct's members.
        try self.visit(node.body)

        // Retrieve the symbol of each of the struct's member.
        let members = node.body.symbols.map { name -> (String, QualifiedType) in
            let symbols = node.innerScope![name]
            let type    = symbols.count > 1
                ? QualifiedType(type: TypeUnion(symbols.map { sym in sym.type! }))
                : symbols[0].type!
            return (name, type)
        }

        // Create the struct type.
        let structType = TypeFactory.makeStruct(
            name   : node.name,
            members: Dictionary(uniqueKeysWithValues: members))

        // Unify the variable of the struct's TypeName (created by the NominalTypeFinder) with the
        // StructType we juste created.
        try self.environment.unify(
            node.type!,
            QualifiedType(type: TypeFactory.makeName(name: node.name, type: structType)))

        // Set the symbol's type.
        assert(node.scope![node.name].count == 1)
        node.scope![node.name][0].type = node.type
    }

    /// A substitution map `(TypeVariable) -> UnqualifiedType`.
    var environment: Substitution

}

/// Solve the type constraint system of a module.
///
/// This visitor analyzes all expressions and tries to infer their types based on the context they
/// are used in. This task is equivalent to solving a constraint system where each operation (e.g.
/// an assignment or a function call) defines a set of constraint on the expressions it touches.
///
/// Note that this visitor requires all declared symbols (types, functions and properties) to have
/// been identified (see `NominalTypeFinder` and `DeclarationTypeCreator`).
struct TypeSolver: ASTVisitor {

    init(environment: Substitution) {
        self.environment = environment
    }

    mutating func visit(_ node: FunDecl) throws {
        let codomain = (node.type!.unqualified as! FunctionType).codomain
        self.returnTypes.push((node.scope!, codomain))
        try self.visit(node.body)
        self.returnTypes.pop()
    }

    // NOTE: There's no need to visit ParamDecl nodes, since we don't support parameter default
    // values yet. When we'll do, we'll have to do something similar as what's being done for
    // property declarations.

    mutating func visit(_ node: PropDecl) throws {
        // If there's an initial binding, we infer the type it produces.
        if let (bindingOp, initialValue) = node.initialBinding {
            // Infer the initial value's type.
            try self.visit(initialValue)
            let rvalue = (initialValue as! TypedNode).type!

            // Infer the property's type from its binding.
            let result = inferBindingTypes(
                lvalue: node.type!,
                op    : bindingOp,
                rvalue: rvalue)
            try self.environment.unify(rvalue    , result.rvalue)
            try self.environment.unify(node.type!, result.lvalue)
        }

        // If inference yielded several choices, choose the most restrictive options for each
        // distinct unqualified type.
        if let union = node.type!.unqualified as? TypeUnion {
            try self.environment.unify(node.type!, mostRestrictiveVariants(of: union))
        }
    }

    mutating func visit(_ node: BindingStmt) throws {
        // Infer the type of the rvalue and lvalue separately.
        try self.traverse(node)
        let lvalue = (node.lvalue as! TypedNode).type!
        let rvalue = (node.rvalue as! TypedNode).type!

        // Propagate type constraints implied by the binding operator.
        let result = inferBindingTypes(lvalue: lvalue, op: node.op, rvalue: rvalue)
        try self.environment.unify(lvalue, result.lvalue)
        try self.environment.unify(rvalue, result.rvalue)
    }

    mutating func visit(_ node: ReturnStmt) throws {
        // If "Nothing" is the expected return type, the statement shouldn't return any value.
        if self.returnTypes.last.type.unqualified === BuiltinScope.AnzenNothing {
            guard node.value == nil else {
                throw InferenceError(
                    reason  : "unexpected return value in procedure",
                    location: node.location)
            }
        } else {
            guard let value = node.value else {
                throw InferenceError(
                    reason  : "missing return value",
                    location: node.location)
            }

            try self.visit(value)
            let returnType = (value as! TypedNode).type!
            try self.environment.unify(self.returnTypes.last.type, returnType)

            // TODO: Handle the "from <scope_name>" syntax.
        }
    }

    mutating func visit(_ node: CallExpr) throws {
        // Infer the type of each passed argument.
        try self.visit(node.arguments)
        let argumentTypes = node.arguments.map { $0.type! }

        // If we didn't infer a return type yet, we create a fresh variale.
        if node.type == nil {
            node.type = TypeFactory.makeVariants(of: TypeVariable())
        }

        // Infer the type of the callee.
        try self.visit(node.callee)
        let calleeType = (node.callee as! TypedNode).type!
        let prospects  = calleeType.unqualified is TypeUnion
            ? Array(calleeType.unqualified as! TypeUnion)
            : [calleeType]

        // For each type the callee can represent, we identify which are callable candidates.
        var candidates: [FunctionType]  = []
        for signature in prospects {
            switch signature.unqualified {
            // All function signatures are candidates.
            case let functionType as FunctionType:
                candidates.append(functionType)

            // If the signature is a type name, the callee is used as an initializer. Therefore
            // all the type's initializers become candidate.
            case _ as TypeName:
                fatalError("TODO")

            // If the prospect doesn't fall in one of the above categories, it isn't callable.
            default:
                break
            }
        }

        // Once we've got candidates, we filter out those whose profile doesn't match the call.
        let compatibleCandidates = candidates.filter { signature in
            // Check if the number of parameters matches.
            guard signature.domain.count == node.arguments.count else { return false }

            // Check if the labels match.
            guard (0 ..< signature.domain.count).forAll({ i in
                signature.domain[i].label == node.arguments[i].label
            }) else {
                return false
            }

            return true
        }

        // Among compatible signatures, we have to specialize the generic ones.
        let choices = (argumentTypes + [node.type!]).map {
            return $0.unqualified is TypeUnion
                ? Array($0.unqualified as! TypeUnion)
                : [$0]
        }

        var specializedCandidates: [FunctionType] = []
        for candidate in compatibleCandidates {
            let walked = self.environment.reify(
                QualifiedType(type: candidate, qualifiedBy: [.mut, .shd, .ref]))
            let unspecialized = walked.unqualified as! FunctionType

            for types in Product(choices) {
                let specializer = QualifiedType(
                    type: TypeFactory.makeFunction(
                        domain: zip(unspecialized.domain, types.dropLast())
                            .map { (arg) -> (label: String?, type: QualifiedType) in
                                return (arg.0.label, arg.1)
                        },
                        codomain: types.last!),
                    qualifiedBy: walked.qualifiers)

                if let specialized = specialize(walked, with: specializer) {
                    specializedCandidates.append(specialized.unqualified as! FunctionType)
                }

                // Let's take a moment to admire the complexity of that code ... 🤯
            }
        }

        // Once we've got specialized candidates, we filter out those whose domain and codomain
        // don't match the inferred arguments and return types.
        let selectedCandidates = specializedCandidates.filter { signature in
            // Check the domain.
            for i in 0 ..< signature.domain.count {
                guard self.environment.matches(signature.domain[i].type, argumentTypes[i]) else {
                    return false
                }
            }

            // Check the codomain.
            guard self.environment.matches(signature.codomain, node.type!) else {
                return false
            }

            return true
        }

        // We can't go further if we couldn't select any candidate.
        guard !selectedCandidates.isEmpty else {
            // Reify all profiles for a better error reporting.
            let profiles = TypeUnion(Product(choices).map { (types) -> QualifiedType in
                return QualifiedType(
                    type: TypeFactory.makeFunction(
                        domain: (0 ..< node.arguments.count).map { i in
                            (node.arguments[i].label, self.environment.reify(types[i]))
                        },
                        codomain: self.environment.reify(types.last!)))
            })

            var reason = "no candidate to call '\(node.callee)' "       +
                         "with any of the possible profiles; I tried:\n" +
                         profiles.prefix(5).map({ "\t\($0)" }).joined(separator: "\n")
            if profiles.count > 5 {
                reason += "\n\t...\namong \(profiles.count - 5) other profile(s)"
            }

            throw InferenceError(reason: reason, location: node.location)
        }

        // Unify arguments with the domains of the selected candidates, and the return type with
        // their codomain (when applicable).
        for i in 0 ..< node.arguments.count {
            let domains = QualifiedType(
                type: TypeUnion.flattening(selectedCandidates.map { $0.domain[0].type }))
            try self.environment.unify(domains, argumentTypes[i])
        }
        let codomains = QualifiedType(
            type: TypeUnion.flattening(selectedCandidates.flatMap { $0.codomain }))
        try self.environment.unify(codomains, node.type!)

        // Set the type of the callee.
        // Note that we can't unify here, because the callee's type might be associated with the
        // symol of the function (or type) used as a callee. If that type is overloaded or
        // generic, unification would remove overloads that weren't compatible with this call.
        let qualifiedCandidates = selectedCandidates.map {
            QualifiedType(type: $0, qualifiedBy: [.mut, .shd, .ref])
        }
        (node.callee as? TypedNode)?.type = qualifiedCandidates.count > 1
            ? QualifiedType(type: TypeUnion(qualifiedCandidates))
            : qualifiedCandidates[0]
    }

    mutating func visit(_ node: CallArg) throws {
        // If we didn't infer a type for the passed type yet, we create a fresh variable.
        if node.type == nil {
            node.type = TypeFactory.makeVariants(of: TypeVariable())
        }

        // Infer the type of the argument's value.
        try self.visit(node.value)
        let argumentType = (node.value as! TypedNode).type!

        // A call argument can be seen as a binding statement, where the argument's value is the
        // rvalue and the passed argument is the lvalue. Since we store the type of the passed as
        // the node's type, we use it as the lvalue.
        let result = inferBindingTypes(
            lvalue: node.type!,
            op    : node.bindingOp ?? .cpy,
            rvalue: argumentType)

        try self.environment.unify(node.type!  , result.lvalue)
        try self.environment.unify(argumentType, result.rvalue)
    }

    mutating func visit(_ node: Ident) throws {
        // The type of identifiers may be dissociated from that of their corresponding symbols
        // when working with generics. Therefore we've to make sure not to re-associate them.
        if node.type == nil {
            let symbols = node.scope![node.name]
            node.type = symbols.count > 1
                ? QualifiedType(type: TypeUnion(symbols.map { sym in sym.type! }))
                : symbols[0].type!
        }
    }

    mutating func visit(_ node: Literal<Int>) throws {
        node.type = QualifiedType(type: BuiltinScope.AnzenInt, qualifiedBy: [.cst, .stk, .val])
    }

    mutating func visit(_ node: Literal<Bool>) throws {
        node.type = QualifiedType(type: BuiltinScope.AnzenBool, qualifiedBy: [.cst, .stk, .val])
    }

    mutating func visit(_ node: Literal<String>) throws {
        node.type = QualifiedType(type: BuiltinScope.AnzenString, qualifiedBy: [.cst, .stk, .val])
    }

    // MARK: Internals

    /// A substitution map `(TypeVariable) -> UnqualifiedType`.
    var environment: Substitution

    /// A stack of pairs of scopes and expected return types.
    ///
    /// We use this stack as we visit scopes that may return a value (e.g. functions), so that we
    /// can unify the expected type of all return statements.
    var returnTypes: Stack<(scope: Scope, type: QualifiedType)> = []

}

/// An AST walker that reifies the type of all typed nodes.
struct TypeReifier: ASTVisitor {

    func reify(typeOf node: TypedNode) {
        if let type = node.type {
            node.type = self.environment.reify(type)
        }
    }

    mutating func visit(_ node: FunDecl) {
        self.reify(typeOf: node)
        try! self.traverse(node)
    }

    mutating func visit(_ node: ParamDecl) {
        self.reify(typeOf: node)
        try! self.traverse(node)
    }

    mutating func visit(_ node: PropDecl) {
        self.reify(typeOf: node)
        try! self.traverse(node)
    }

    mutating func visit(_ node: StructDecl) {
        self.reify(typeOf: node)
        try! self.traverse(node)
    }

    mutating func visit(_ node: QualSign) {
        self.reify(typeOf: node)
        try! self.traverse(node)
    }

    func visit(_ node: Ident) {
        self.reify(typeOf: node)
    }

    let environment: Substitution

}

// MARK: Internals

fileprivate func mostRestrictiveVariants(of union: TypeUnion) -> QualifiedType {
    // Isolate unqualified types by erasing their qualifiers.
    let distinct = Set(union.map { QualifiedType(type: $0.unqualified, qualifiedBy: []) })

    var choices: [QualifiedType] = []
    for type in distinct {
        for combination in TypeQualifier.combinations {
            let t = QualifiedType(type: type.unqualified, qualifiedBy: combination)
            if union.contains(t) {
                choices.append(t)
                break
            }
        }
    }

    return choices.count > 1
        ? QualifiedType(type: TypeUnion(choices))
        : choices[0]
}

fileprivate func analyzeTypeAnnotation(_ node: Node) throws -> QualifiedType {
    switch node {
    case let qualifiedSignature as QualSign:
        return try! analyzeQualifiedSignature(qualifiedSignature)
    case _ as FunSign:
        fatalError("TODO")
    case let identifier as Ident:
        return try! analyzeIdentifier(identifier)
    default:
        fatalError("unexpected node for type annotation")
    }
}

fileprivate func analyzeQualifiedSignature(_ node: QualSign) throws -> QualifiedType {
    // First we need a type for the unqualified part of the signature. Either it is explicitly
    // defined, in which case we'll analyze it, or if it isn't we'll use a fresh variable.
    let unqualifiedSignature: UnqualifiedType
    switch node.signature {
    case let identifier as Ident:
        unqualifiedSignature = try analyzeIdentifier(identifier).unqualified

    case _ as FunSign:
        fatalError("TODO")

    default:
        unqualifiedSignature = TypeFactory.makeVariants(of: TypeVariable()).unqualified
    }

    // The unqualified part should be a type union and not a type placeholder, as qualifiers shall
    // not be set on generic placholders.
    guard unqualifiedSignature is TypeUnion else {
        assert(unqualifiedSignature is TypePlaceholder)
        throw InferenceError(
            reason  : "invalid use of qualifiers on generic placeholder",
            location: node.location)
    }

    // Filter out variants that aren't compatible with the explicit qualifiers.
    let variants = (unqualifiedSignature as! TypeUnion).filter {
        $0.qualifiers.intersection(node.qualifiers) == node.qualifiers
    }
    guard !variants.isEmpty else {
        throw InferenceError(
            reason  : "invalid qualifiers",
            location: node.location)
    }

    node.type = variants.count > 1
        ? QualifiedType(type: TypeUnion(variants))
        : variants[0]
    return node.type!
}

fileprivate func analyzeIdentifier(_ node: Ident) throws -> QualifiedType {
    // The symbol should be typed with an instance of TypeName or TypePlaceholder. Note that we
    // only check first symbol named after the identifier. That's because type symbols can't be
    // overloaded. So if the first symbol isn't typed with a TypeName, the other won't be as well.
    let symbols = node.scope![node.name]
    guard symbols.count >= 1, let symbolType = symbols[0].type else {
        throw InferenceError(
            reason  : "use of undeclared type '\(node.name)'",
            location: node.location)
    }

    if let typeName = symbolType.unqualified as? TypeName {
        node.type = TypeFactory.makeVariants(of: typeName.type)
    } else if symbolType.unqualified is TypePlaceholder {
        node.type = symbolType
    } else {
        throw InferenceError(
            reason  : "'\(node.name)' is not a type",
            location: node.location)
    }

    return node.type!
}

/// Infer all possible types of the lvalue and rvalue of a binding from partial information.
fileprivate func inferBindingTypes(lvalue: QualifiedType, op: Operator, rvalue: QualifiedType)
    -> (lvalue: QualifiedType, rvalue: QualifiedType)
{
    // NOTE: There are various illegal use of the binding operators that we could detect here. For
    // instance, it is illegal to move a `@ref` rvalue. But we'll let that errors be checked by
    // the reference checker instead, to preserve the compartmentalization of compiling passes.

    let ltypes = lvalue.unqualified is TypeUnion
        ? Array(lvalue.unqualified as! TypeUnion)
        : [lvalue]
    let rtypes = rvalue.unqualified is TypeUnion
        ? Array(rvalue.unqualified as! TypeUnion)
        : [rvalue]

    let lresult: [QualifiedType]
    let rresult: [QualifiedType]

    switch op {
    // A copy binding preserves the rvalue's type, but takes the lvalue's type qualifiers. The
    // lvalue's type can have any qualifier.
    case .cpy:
        // The lvalue's qualifiers are preserved.
        lresult = (ltypes * rtypes).map { lhs, rhs in
            return QualifiedType(type: rhs.unqualified, qualifiedBy: lhs.qualifiers)
        }

        // The rvalue's type can be any of the lvalue's type variants.
        rresult = (ltypes * TypeQualifier.combinations).map { (pair) -> QualifiedType in
            let (lhs, qualifiers) = pair
            return QualifiedType(type: lhs.unqualified, qualifiedBy: qualifiers)
        }

    // A move binding always bind `@val` expressions on its to `@val` variables on its left.
    case .mov:
        // The lvalue's type can be any `@val` variant of the rvalue's type.
        lresult = (rtypes * TypeQualifier.combinations).flatMap { (pair) -> QualifiedType? in
            let (rhs, qualifiers) = pair
            return qualifiers.contains(.val)
                ? QualifiedType(type: rhs.unqualified, qualifiedBy: qualifiers)
                : nil
        }

        // The rvalue's type can be any `@val` variant of the lvalue's type.
        rresult = (ltypes * TypeQualifier.combinations).flatMap { (pair) -> QualifiedType? in
            let (lhs, qualifiers) = pair
            return qualifiers.contains(.val)
                ? QualifiedType(type: lhs.unqualified, qualifiedBy: qualifiers)
                : nil
        }

    // A reference binding always produces `@ref` lvalues from any rvalue.
    case .ref:
        // The lvalue's type can be any `@ref` variant of the rvalue's type.
        lresult = (rtypes * TypeQualifier.combinations).flatMap { (pair) -> QualifiedType? in
            let (rhs, qualifiers) = pair
            return qualifiers.contains(.ref)
                ? QualifiedType(type: rhs.unqualified, qualifiedBy: qualifiers)
                : nil
        }

        // The rvalue's type can be any of the lvalue's type variants.
        rresult = (ltypes * TypeQualifier.combinations).map { (pair) -> QualifiedType in
            let (lhs, qualifiers) = pair
            return QualifiedType(type: lhs.unqualified, qualifiedBy: qualifiers)
        }

    default:
        fatalError("unexpected binding operator")
    }

    return (
        lresult.count > 1
            ? QualifiedType(type: TypeUnion(lresult))
            : lresult[0],
        rresult.count > 1
            ? QualifiedType(type: TypeUnion(rresult))
            : rresult[0])
}

fileprivate func specialize(
    _ unspecialized : QualifiedType,
    with specializer: QualifiedType) -> QualifiedType?
{
    var specializations: [String: QualifiedType] = [:]
    return specialize(unspecialized, with: specializer, specializations: &specializations)
}

fileprivate func specialize(
    _ unspecialized : QualifiedType,
    with specializer: QualifiedType,
    specializations : inout [String: QualifiedType]) -> QualifiedType?
{
    guard unspecialized.isGeneric else {
        return unspecialized
    }

    assert(!(specializer.unqualified is TypeUnion))

    switch unspecialized.unqualified {
    case let (typePlaceholder as TypePlaceholder):
        // Return the previously chosen specialization, if any.
        if let t = specializations[typePlaceholder.name] {
            return t
        }

        // FIXME: Make sure we don't create multiple variables for the same placeholder.
        specializations[typePlaceholder.name] = specializer.isGeneric
            ? TypeFactory.makeVariants(of: TypeVariable())
            : specializer
        return specializations[typePlaceholder.name]

    case let (functionType as FunctionType):
        guard let specializerFunction = specializer.unqualified as? FunctionType else {
            return nil
        }

        // Create a new specialization list that overrides the current placeholders.
        var subSpecializations = specializations
        for placehoder in functionType.placeholders {
            subSpecializations[placehoder] = nil
        }

        var domain: [(label: String?, type: QualifiedType)] = []
        for (original, replacement) in zip(functionType.domain, specializerFunction.domain) {
            guard original.label == replacement.label else { return nil }
            guard let specialized = specialize(
                original.type, with: replacement.type,
                specializations: &subSpecializations)
                else {
                    return nil
            }
            domain.append((original.label, specialized))
        }

        guard let codomain = specialize(
            functionType.codomain, with: specializerFunction.codomain,
            specializations: &subSpecializations)
            else {
                return nil
        }

        // Store all specializations that aren't part of the functions' placeholders.
        for sub in subSpecializations {
            if !functionType.placeholders.contains(sub.key) {
                specializations[sub.key] = sub.value
            }
        }

        return QualifiedType(
            type       : TypeFactory.makeFunction(domain: domain, codomain: codomain),
            qualifiedBy: unspecialized.qualifiers)

    default:
        assertionFailure()
        break
    }

    return nil
}
