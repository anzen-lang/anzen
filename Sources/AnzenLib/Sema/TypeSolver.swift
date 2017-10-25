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
        if let (bindingOp, bindingValue) = node.initialBinding {
            print(bindingOp)
            print(bindingValue)

            // TODO
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

    // MARK: Internals

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
                    .filter { !$0.intersection(node.qualifiers).isEmpty }
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

