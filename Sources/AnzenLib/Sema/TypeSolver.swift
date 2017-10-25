struct Substitution {

    mutating func unify(_ t: QualifiedType, _ u: QualifiedType) throws {
        let a = self.walked(t)
        let b = self.walked(u)

        // Make sure only type unions and type names don't have any type qualifier.
        assert(!a.qualifiers.isEmpty || (a.unqualified is TypeUnion))
        assert(!b.qualifiers.isEmpty || (b.unqualified is TypeUnion))

        // If `a` and `b` are equal they're already unified.
        guard a != b else { return }

        switch (a.unqualified, b.unqualified) {
        case let (variable as TypeVariable, union as TypeUnion):
            let matching = union.filter { $0.qualifiers == a.qualifiers }
            guard matching.count > 0 else {
                throw CompilerError.inferenceError
            }
            union.formIntersection(TypeUnion(matching))
            self.storage[variable] = matching.count > 1
                ? union
                : matching[0].unqualified

        case let (variable as TypeVariable, _):
            guard a.qualifiers == b.qualifiers else { throw CompilerError.inferenceError }
            self.storage[variable] = b.unqualified

        case (_, _ as TypeVariable):
            try self.unify(b, a)

        case let (lhs as TypeUnion, rhs as TypeUnion):
            let walkedL = lhs.map({ self.walked($0) })
            let walkedR = rhs.map({ self.walked($0) })

            // Compute the intersection of `lhs` with `rhs`.
            let result = (walkedL * walkedR).flatMap({ self.matches($0.0, $0.1) ? $0.0 : nil })
            guard result.count > 0 else {
                throw CompilerError.inferenceError
            }

            // Unify the variables of `lhs` with the compatible variables in `rhs`.
            for l in walkedL {
                if l.unqualified is TypeVariable {
                    do {
                        try self.unify(l, QualifiedType(type: TypeUnion(walkedR)))
                    } catch(CompilerError.inferenceError) {
                        continue
                    }
                }
            }

            // Unify the variables of `rhs` with the compatible variables in `lhs`.
            for r in walkedR {
                if r.unqualified is TypeVariable {
                    do {
                        try self.unify(r, QualifiedType(type: TypeUnion(walkedL)))
                    } catch(CompilerError.inferenceError) {
                        continue
                    }
                }
            }

            // `lhs = rhs = lhs & rhs`
            lhs.formIntersection(TypeUnion(result))
            rhs.formIntersection(TypeUnion(result))

        case let (union as TypeUnion, _):
            let result = union.flatMap({ self.matches($0, b) ? $0 : nil })
            union.formIntersection(TypeUnion(result))

        case let (_, union as TypeUnion):
            let result = union.flatMap({ self.matches(a, $0) ? $0 : nil })
            union.formIntersection(TypeUnion(result))

        default:
            throw CompilerError.inferenceError
        }
    }

    func matches(_ t: QualifiedType, _ u: QualifiedType) -> Bool {
        let a = self.walked(t)
        let b = self.walked(u)

        // If `a` and `b` are equal they're already unified.
        guard a != b else { return true }

        switch (a.unqualified, b.unqualified) {
        case let (_ as TypeVariable, union as TypeUnion):
            return union.contains(where: { self.matches(a, $0) })

        case (_ as TypeVariable, _):
            return a.qualifiers == b.qualifiers

        case (_, _ as TypeVariable):
            return self.matches(b, a)

        case let (union as TypeUnion, _):
            return union.contains(where: { self.matches($0, b) })

        case let (_, union as TypeUnion):
            return union.contains(where: { self.matches(a, $0) })

        case let (lhs as FunctionType, rhs as FunctionType):
            let result = a.qualifiers == b.qualifiers
                && lhs.domain.count == rhs.domain.count
                && zip(lhs.domain, rhs.domain).forAll({ l, r in
                       l.label == r.label && self.matches(l.type, r.type)
                   })
            guard result else { return false }
            guard let l = lhs.codomain, let r = rhs.codomain else {
                return (lhs.codomain == nil) && (rhs.codomain == nil)
            }
            return self.matches(l, r)

        case let (lhs as StructType, rhs as StructType):
            return a.qualifiers == b.qualifiers
                && lhs.name == rhs.name
                && lhs.members.keys == rhs.members.keys
                && lhs.members.forAll({ self.matches($0.value, rhs.members[$0.key]!) })

        default:
            return false
        }
    }

    // MARK: Internals

    private func walked(_ t: QualifiedType) -> QualifiedType {
        // Find the unified value of the unqualified type.
        let unqualified = self.walked(t.unqualified)

        // If the unqualified type is an union, make sure all members are qualified appropriately.
        if let union = unqualified as? TypeUnion {
            assert(t.qualifiers.isEmpty || union.forAll({ $0.qualifiers == t.qualifiers }))
        }

        // Otherwise we return the walked qualified type.
        return QualifiedType(type: unqualified, qualifiedBy: t.qualifiers)
    }

    private func walked(_ t: UnqualifiedType) -> UnqualifiedType {
        if let variable     = t as? TypeVariable,
           let unifiedValue = self.storage[variable]
        {
            return self.walked(unifiedValue)
        } else {
            return t
        }
    }

    private var storage: [TypeVariable: UnqualifiedType] = [:]

}

public struct TypeSolver: ASTVisitor {

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
                    .filter { !$0.qualifiers.intersection(node.qualifiers).isEmpty }

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
