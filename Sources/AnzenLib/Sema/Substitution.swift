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
            lhs.formIntersection(TypeUnion(result))
            rhs.formIntersection(TypeUnion(result))

            // Unify the variables of `lhs` with the compatible variables in `rhs`.
            let qualifiedR = QualifiedType(type: TypeUnion(walkedR))
            for l in walkedL.lazy.filter({ $0.unqualified is TypeVariable }) {
                try? self.unify(l, qualifiedR)
            }

            // Unify the variables of `rhs` with the compatible variables in `lhs`.
            let qualifiedL = QualifiedType(type: TypeUnion(walkedL))
            for r in walkedR.lazy.filter({ $0.unqualified is TypeVariable }) {
                try? self.unify(r, qualifiedL)
            }

        case let (union as TypeUnion, _):
            var result: [QualifiedType] = []
            for l in union {
                if let _ = try? self.unify(l, b) {
                    result.append(l)
                }
            }
            guard result.count > 0 else {
                throw CompilerError.inferenceError
            }
            union.formIntersection(TypeUnion(result))

        case (_, _ as TypeUnion):
            try? self.unify(b, a)

        case (_ as FunctionType, _ as FunctionType):
            fatalError("TODO")

        case let (lhs as StructType, rhs as StructType):
            guard a.qualifiers == b.qualifiers
                && lhs.name == rhs.name
                && lhs.members.keys == rhs.members.keys
                else {
                    throw CompilerError.inferenceError
            }
            for (key, member) in lhs.members {
                try self.unify(member, rhs.members[key]!)
            }

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

    public func reify(_ type: QualifiedType) -> QualifiedType {
        let walked = self.walked(type)

        switch walked.unqualified {
        case let union as TypeUnion:
            let reifiedUnion = TypeUnion(union.map { self.reify($0) })
            return reifiedUnion.count > 1
                ? QualifiedType(type: reifiedUnion)
                : reifiedUnion.first(where: { _ in true })!

        default:
            return walked
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
