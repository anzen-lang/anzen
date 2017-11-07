import SwiftProductGenerator

public struct TypeSolver: ASTVisitor {

    /// Infer the type annotations of a module AST.
    public mutating func infer(_ module: ModuleDecl) throws {
        try self.visit(module)

        // TODO: Fixed point.

        // Reify all type annotations.
        var reifier = TypeReifier(using: self.environment)
        try! reifier.visit(module)
    }

    public mutating func visit(_ node: FunDecl) throws {
        // Create a placeholder type for each of the function's generic placeholders.
        for placeholderName in node.placeholders {
            let varID = VariableID.named(node.innerScope!, placeholderName)
            if self.symbolTypes[varID] == nil {
                let placeholder = TypePlaceholder(named: placeholderName)
                self.symbolTypes [varID] = QualifiedType(type: placeholder)
            }
        }

        // Get the type of each parameter.
        var domain: [(label: String?, type: QualifiedType)] = []
        for child in node.parameters {
            let parameter = child as! ParamDecl
            try self.visit(parameter)
            domain.append((parameter.label, parameter.type!))
        }

        // The codomain is either a signature to analyse, or `Nothing`.
        var codomain: QualifiedType
        if node.codomain != nil {
            codomain = try self.analyseTypeAnnotation(node.codomain!)
            if let union = codomain.unqualified as? TypeUnion {
                codomain = mostRestrictiveVariants(of: union)
            }
        } else {
            codomain = QualifiedType(
                type       : BuiltinScope.AnzenNothing,
                qualifiedBy: [.cst, .stk, .val])
        }

        // Once we've computed the domain and codomain of the function's signature, we can create
        // a type for the function itself. Note that functions (unless global) are actually
        // garbage collected objects. Therefore they are declared with `@mut @shd @ref`.
        node.type = QualifiedType(
            type: TypeFactory.makeFunction(
                placeholders: Set(node.placeholders),
                domain      : domain,
                codomain    : codomain),
            qualifiedBy: [.mut, .shd, .ref])

        // As functions may be overloaded, we can't unify the function type we've created with the
        // function's symbol directly. Instead, we should create a type union so as to handle
        // overloaded signatures.
        let varID = VariableID.named(node.scope!, node.name)
        if let symbolType = self.symbolTypes[varID] {
            guard let overloads = symbolType.unqualified as? TypeUnion else {
                throw CompilerError.inferenceError(file: #file, line: #line)
            }
            overloads.insert(node.type!)
        } else {
            self.symbolTypes[varID] = QualifiedType(type: TypeUnion([node.type!]))
        }

        // Visit the body of the function.
        self.returnTypes.push((node.scope!, codomain))
        try self.visit(node.body as! Block)
        self.returnTypes.pop()

        // NOTE: Checking whether or not the function has a return statement in all its execution
        // paths shouldn't be performed here, but in the pass that analyses the program's CFG.

        // Set the symbol's type.
        node.scope![node.name].first(where: { $0 === node })?.type = node.type
    }

    public mutating func visit(_ node: ParamDecl) throws {
        // Infer the type of the parameter based on its annotation.
        var inferred = try self.analyseTypeAnnotation(node.typeAnnotation)
        if let union = inferred.unqualified as? TypeUnion {
            inferred = mostRestrictiveVariants(of: union)
        }

        // Parameter declarations are typed with the same type as that of the symbol they declare.
        let varID = VariableID.named(node.scope!, node.name)
        if self.symbolTypes[varID] == nil {
            self.symbolTypes[varID] = inferred
        }

        // NOTE: Since we don't support parameter with default values yet, there's no need to
        // unify the symbol of the parameter with the inferred type yet, as there's no constraint
        // to be propagated.

        node.type = inferred
        node.scope![node.name].first(where: { $0 === node })?.type = node.type
    }

    public mutating func visit(_ node: PropDecl) throws {
        // Property declarations are typed with the same type as that of the symbol they declare.
        node.type = self.getSymbolType(scope: node.scope!, name: node.name)

        var inferred: QualifiedType? = nil

        // If there's a type annotation, we use it "as is" to type the property.
        if let annotation = node.typeAnnotation {
            inferred = try self.analyseTypeAnnotation(annotation)
        }

        // If there's an initial binding, we infer the type it produces.
        if let (bindingOp, initialValue) = node.initialBinding {
            // Infer the initial value's type.
            let rvalue = try self.analyseValueExpression(initialValue)

            // Infer the property's type from its binding.
            let result = inferBindingTypes(
                lvalue: inferred ?? node.type!,
                op    : bindingOp,
                rvalue: rvalue)
            try self.environment.unify(rvalue, result.rvalue)
            if inferred != nil {
                try self.environment.unify(inferred!, result.lvalue)
            } else {
                inferred = result.lvalue
            }
        }

        // If we couldn't get any additional type information, we use the type of the symbol.
        var declarationType = inferred ?? node.type!

        // If inference yielded several choices, choose the most restrictive options for each
        // distinct unqualified type.
        if let union = declarationType.unqualified as? TypeUnion {
            declarationType = mostRestrictiveVariants(of: union)
        }

        // Unify the symbol's type with that of its declaration.
        try self.environment.unify(node.type!, declarationType)
        node.scope![node.name].first(where: { $0 === node })?.type = node.type
    }

    public mutating func visit(_ node: BindingStmt) throws {
        let lvalue = try self.analyseValueExpression(node.lvalue)
        let rvalue = try self.analyseValueExpression(node.rvalue)

        // Propagate type constraints implied by the binding operator.
        let result = inferBindingTypes(lvalue: lvalue, op: node.op, rvalue: rvalue)
        try self.environment.unify(lvalue, result.lvalue)
        try self.environment.unify(rvalue, result.rvalue)
    }

    public mutating func visit(_ node: ReturnStmt) throws {
        // If "Nothing" is the expected return type, the statement shouldn't return any value.
        if self.returnTypes.last.type.unqualified === BuiltinScope.AnzenNothing {
            guard node.value == nil else {
                throw CompilerError.inferenceError(file: #file, line: #line)
            }
        }

        guard let value = node.value else {
            throw CompilerError.inferenceError(file: #file, line: #line)
        }

        let returnType = try self.analyseValueExpression(value)
        try self.environment.unify(self.returnTypes.last.type, returnType)

        // TODO: Handle the "from <scope_name>" syntax.
    }

    // MARK: Internals

    private mutating func analyseValueExpression(
        _ expr: Node, asCallee: Bool = false) throws -> QualifiedType
    {
        // Expressions should be typed nodes.
        assert(expr is TypedNode)

        switch expr {
        case let literal as Literal<Int>:
            literal.type = QualifiedType(
                type: BuiltinScope.AnzenInt, qualifiedBy: [.cst, .stk, .val])
            return literal.type!

        case let literal as Literal<Bool>:
            literal.type = QualifiedType(
                type: BuiltinScope.AnzenBool, qualifiedBy: [.cst, .stk, .val])
            return literal.type!

        case let literal as Literal<String>:
            literal.type = QualifiedType(
                type: BuiltinScope.AnzenString, qualifiedBy: [.cst, .stk, .val])
            return literal.type!

        case let node as Ident:
            // The type of identifiers may be dissociated from that of their corresponding symbols
            // when working with generics. Therefore we've to make sure not to re-associate them.
            if node.type == nil {
                node.type = self.getSymbolType(scope: node.scope!, name: node.name)
            }

            // If the node is used as callee (in a call or subscript expression) or owner (in a
            // select expression), we should return the type associated with the typename,
            // otherwise the builtin metatype `Type`.
            if let typeName = node.type!.unqualified as? TypeName {
                node.type = asCallee
                    ? QualifiedType(type: typeName.type, qualifiedBy: [.cst, .stk, .val])
                    : QualifiedType(type: BuiltinScope.AnzenType, qualifiedBy: [.cst, .stk, .val])
            }

            return node.type!

        case let node as CallArg:
            // If we didn't infer a type for the passed type yet, we create a fresh variable.
            if node.type == nil {
                node.type = TypeFactory.makeVariants(of: TypeVariable())
            }

            // Infer the type of the argument's value.
            let argumentType = try self.analyseValueExpression(node.value)

            // A call argument can be seen as a binding statement, where the argument's value is
            // the rvalue and the passed argument is the lvalue. Since we store the type of the
            // passed argument is stored as the node's type, we use it as the lvalue.
            let result = inferBindingTypes(
                lvalue: node.type!,
                op    : node.bindingOp ?? .cpy,
                rvalue: argumentType)

            try self.environment.unify(node.type!, result.lvalue)
            try self.environment.unify(argumentType, result.rvalue)
            return node.type!

        case let node as CallExpr:
            return try self.analyseCallExpression(node)

        default:
            fatalError("unexpected node for expression")
        }
    }

    private mutating func analyseCallExpression(_ node: CallExpr) throws -> QualifiedType {
        // Infer the type of each argument (as an rvalue).
        let argumentTypes = try node.arguments.map { try self.analyseValueExpression($0) }

        // If we didn't infer a return type yet, we create a fresh variale.
        if node.type == nil {
            node.type = TypeFactory.makeVariants(of: TypeVariable())
        }

        // Infer the type of the callee.
        let calleeType = try self.analyseValueExpression(node.callee, asCallee: true)
        let prospects = calleeType.unqualified is TypeUnion
            ? Array(calleeType.unqualified as! TypeUnion)
            : [calleeType]

        // For each type the callee can represent, we identify which are callable candidates.
        var candidates       : [FunctionType] = []
        var selectedCodomains: [QualifiedType] = []
        for signature in prospects {
            switch signature.unqualified {
            // All function signatures are candidates.
            case let functionType as FunctionType:
                candidates.append(functionType)

            // If the prospect is a variable, it may represent a function type whose codomain has
            // yet to be inferred. Therefore we add a fresh variable to the set of codomains.
            case _ as TypeVariable:
                selectedCodomains.append(TypeFactory.makeVariants(of: TypeVariable()))

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
            for i in 0 ..< signature.domain.count {
                guard signature.domain[i].label == (node.arguments[i] as! CallArg).label else {
                    return false
                }
            }

            return true
        }

        // Among compatible signatures, we may have to specialize the generic ones.
        var choices = argumentTypes.map {
            return $0.unqualified is TypeUnion
                ? Array($0.unqualified as! TypeUnion)
                : [$0]
        }
        choices += node.type!.unqualified is TypeUnion
            ? [Array(node.type!.unqualified as! TypeUnion)]
            : [[node.type!]]

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
            // Check the codomain.
            guard self.environment.matches(signature.codomain, node.type!) else { return false }

            // Check the domain.
            for i in 0 ..< signature.domain.count {
                guard self.environment.matches(signature.domain[i].type, argumentTypes[i]) else {
                    return false
                }
            }

            return true
        }

        // If we can't find any candidate, we use the codomains we've selected so far (if any).
        guard !selectedCandidates.isEmpty else {
            guard !selectedCodomains.isEmpty else {
                throw CompilerError.inferenceError(file: #file, line: #line)
            }

            let returnType = selectedCodomains.count > 1
                ? QualifiedType(type: TypeUnion(selectedCodomains))
                : selectedCodomains[0]
            try self.environment.unify(node.type!, returnType)
            return returnType
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

        return node.type!
    }

    private mutating func analyseTypeAnnotation(_ annotation: Node) throws -> QualifiedType {
        // Type annotations should be typed nodes.
        assert(annotation is TypedNode)

        // Because type annotations don't unify anything, there's no need to analyse them more
        // than once.
        if let type = (annotation as! TypedNode).type {
            return type
        }

        switch annotation {
        // If the annotation is an identifier, we use the type of its symbol.
        case let node as Ident:
            var symbolType = self.getSymbolType(scope: node.scope!, name: node.name)

            // `symbolType` should be either a union of type variables (if the symbol's type is
            // still unknown), a type name (if it refers to a nominal type), or a type placeholder
            // (if it refers to a generic placeholder). That's because the identifier is used as a
            // type signature, and therefore shouldn't represent a fully qualified type inferred
            // from an expression.
            let unqualified = symbolType.unqualified

            if let typeName = unqualified as? TypeName {
                symbolType = TypeFactory.makeVariants(of: typeName.type)
            } else {
                guard (unqualified is TypeUnion) || (unqualified is TypePlaceholder) else {
                    // The identifier does not represent a type.
                    throw CompilerError.inferenceError(file: #file, line: #line)
                }
            }

            node.type = symbolType
            return symbolType

        case _ as FunSign:
            // TODO
            fatalError("not implemented")

        case let node as QualSign:
            // If the annotation has a signature, we get the unqualified types it designate.
            let variants: [QualifiedType]
            if let signature = node.signature {
                let union = try self.analyseTypeAnnotation(signature)
                assert(union.qualifiers.isEmpty)
                assert(union.unqualified is TypeUnion)
                variants = Array(union.unqualified as! TypeUnion)
                    .filter { $0.qualifiers.intersection(node.qualifiers) == node.qualifiers }

            // Otherwise, if it only specifies qualifiers, we use a type variable.
            } else {
                let variable = TypeVariable()
                variants = TypeQualifier.combinations
                    .filter { $0.intersection(node.qualifiers) == node.qualifiers }
                    .map    { QualifiedType(type: variable, qualifiedBy: $0) }
            }

            // If there's no variant left, the specified qualifiers are invalid.
            guard !variants.isEmpty else {
                throw CompilerError.inferenceError(file: #file, line: #line)
            }

            node.type = variants.count > 1
                ? QualifiedType(type: TypeUnion(variants))
                : variants[0]
            return node.type!

        default:
            fatalError("unexpected node for type annotation")
        }
    }

    private mutating func getSymbolType(scope: Scope, name: String) -> QualifiedType {
        let varID = VariableID.named(scope, name)
        if let type = self.symbolTypes[varID] {
            return type
        } else {
            // Check if the type of the symbol was already inferred (as part of the builtins or
            // imported from another module symbols).
            let symbols = scope[name]
            if symbols[0].type != nil {
                self.symbolTypes[varID] = symbols.count > 1
                    ? QualifiedType(type: TypeUnion(symbols.map({ $0.type! })))
                    : symbols[0].type!

            // Otherwise create a fresh variable.
            } else {
                self.symbolTypes[varID] = TypeFactory.makeVariants(of: TypeVariable())
            }

            return self.symbolTypes[varID]!
        }
    }

    /// A substitution map `(TypeVariable) -> UnqualifiedType`.
    private var environment = Substitution()

    /// A mapping `(VariableID) -> QualifiedType`.
    private var symbolTypes: [VariableID: QualifiedType] = [:]

    /// A mapping `(VariableID) -> TypeVariable`.
    private var placeholders: [VariableID: TypePlaceholder] = [:]

    /// A stack of pairs of scopes and expected return types.
    ///
    /// We use this stack as we visit scopes that may return a value (e.g. functions), so that we
    /// can unify the expected type of all return statements.
    private var returnTypes: Stack<(scope: Scope, type: QualifiedType)> = []

}

// MARK: Internals

/// An enumeration for the IDs we'll use to keep track of type variables.
fileprivate enum VariableID: Hashable {

    case named(Scope, String)

    var hashValue: Int {
        switch self {
        case let .named(scope, name): return scope.hashValue ^ name.hashValue
        }
    }

    static func ==(lhs: VariableID, rhs: VariableID) -> Bool {
        switch (lhs, rhs) {
        case let (.named(lscope, lname), .named(rscope, rname)):
            return (lscope == rscope) && (lname == rname)
        }
    }

}

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

/// An AST walker that reifies the type of all typed nodes.
fileprivate struct TypeReifier: ASTVisitor {

    init(using environment: Substitution) {
        self.environment = environment
    }

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

    mutating func visit(_ node: QualSign) {
        self.reify(typeOf: node)
        try! self.traverse(node)
    }

    func visit(_ node: Ident) {
        self.reify(typeOf: node)
    }

    let environment: Substitution

}
