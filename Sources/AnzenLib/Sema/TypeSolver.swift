public struct TypeSolver: ASTVisitor {

    /// Infer the type annotations of a module AST.
    public mutating func infer(_ module: ModuleDecl) throws {
        try self.visit(module)

        // TODO: Fixed point.

        // Reify all type annotations.
        var reifier = TypeReifier(using: self.environment)
        try! reifier.visit(module)
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
            assert(declarationType.qualifiers.isEmpty)

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

            declarationType = choices.count > 1
                ? QualifiedType(type: TypeUnion(choices))
                : choices[0]
        }

        // Unify the symbol's type with that of its declaration.
        try self.environment.unify(node.type!, declarationType)
    }

    public mutating func visit(_ node: BindingStmt) throws {
        let lvalue = try self.analyseValueExpression(node.lvalue)
        let rvalue = try self.analyseValueExpression(node.rvalue)

        // Propagate type constraints implied by the binding operator.
        let result = inferBindingTypes(lvalue: lvalue, op: node.op, rvalue: rvalue)
        try self.environment.unify(lvalue, result.lvalue)
        try self.environment.unify(rvalue, result.rvalue)
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

        default:
            fatalError("unexpected node for expression")
        }
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
            // still unknown) or a type name. That's because the identifier is used as a type
            // signature, and therefore isn't allowed to be a variable.
            // FIXME: We should probably throw rather than fail the assertion here.
            assert((symbolType.unqualified is TypeUnion) || (symbolType.unqualified is TypeName))

            if let typeName = symbolType.unqualified as? TypeName {
                let variants = TypeQualifier.combinations
                    .map { QualifiedType(type: typeName.type, qualifiedBy: $0) }
                symbolType = QualifiedType(type: TypeUnion(variants))
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
                throw CompilerError.inferenceError
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
        let varID: VariableID = .named(scope, name)
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
                let variable = TypeVariable()
                let variants = TypeQualifier.combinations
                    .map { QualifiedType(type: variable, qualifiedBy: $0) }
                self.symbolTypes[varID] = QualifiedType(type: TypeUnion(variants))
            }

            return self.symbolTypes[varID]!
        }
    }

    /// A substitution map `(TypeVariable) -> UnqualifiedType`.
    private var environment = Substitution()

    /// A mapping `(VariableID) -> TypeUnion`.
    private var symbolTypes: [VariableID: QualifiedType] = [:]

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

/// An AST walker that reifies the type of all typed nodes.
fileprivate struct TypeReifier: ASTVisitor {

    init(using environment: Substitution) {
        self.environment = environment
    }

    func visit(_ node: PropDecl) throws {
        if let type = node.type {
            node.type = self.environment.reify(type)
        }
    }

    let environment: Substitution

}
