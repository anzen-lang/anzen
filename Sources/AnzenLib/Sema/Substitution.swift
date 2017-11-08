class Substitution {

    func unify(_ t: QualifiedType, _ u: QualifiedType) throws {
        let a = self.walked(t)
        let b = self.walked(u)

        // If `a` and `b` are equal they're already unified.
        guard a != b else { return }

        switch (a.unqualified, b.unqualified) {
        case let (variable as TypeVariable, union as TypeUnion):
            // Keep only the types that match the variable.
            var matching = union.filter { $0.qualifiers == a.qualifiers }
            guard matching.count > 0 else {
                throw CompilerError.inferenceError(file: #file, line: #line)
            }
            union.replaceContent(with: Set(matching))

            // Make sure we don't unify a variable with itself.
            matching = matching.filter { $0.unqualified !== variable }
            if matching.count > 0 {
                self.storage[variable] = matching.count > 1
                    ? union
                    : matching[0].unqualified
            }

        case let (variable as TypeVariable, _):
            guard a.qualifiers == b.qualifiers else {
                throw CompilerError.inferenceError(file: #file, line: #line)

            }
            self.storage[variable] = b.unqualified

        case (_, _ as TypeVariable):
            try self.unify(b, a)

        case let (lhs as TypeName, rhs as TypeName):
            if let variable = lhs.type as? TypeVariable {
                self.storage[variable] = rhs.type
            } else if let variable = rhs.type as? TypeVariable {
                self.storage[variable] = lhs.type
            }

        case (_ as TypePlaceholder, _):
            break

        case (_ , _ as TypePlaceholder):
            break

        case let (lhs as TypeUnion, rhs as TypeUnion):
            let walkedL = TypeUnion.flattening(lhs.map({ self.walked($0) }))
            let walkedR = TypeUnion.flattening(rhs.map({ self.walked($0) }))

            // Compute the intersection of `lhs` with `rhs`.
            let result = (walkedL * walkedR).flatMap({ self.matches($0.0, $0.1) ? $0 : nil })
            guard result.count > 0 else {
                throw CompilerError.inferenceError(file: #file, line: #line)
            }
            let newContent = Set(result.map { $0.0 })
            lhs.replaceContent(with: newContent)
            rhs.replaceContent(with: newContent)

            // We now have to unify the we kept from `lhs` (resp. `rhs`) with the compatible types
            // in `rhs` (resp. `lhs`). For instance:
            //
            //     lhs = {@cst $0, @mut $0, @ref $1}
            //     rhs = {@cst T0, @ref T0, @ref T1, @shd T1}
            //
            //                     ▼
            //
            //     lhs = {@cst $0, @ref $1}
            //     rhs = {@cst $0, @ref $1}
            //     $0 -> @cst T0
            //     $1 -> {@ref T0, @ref T1}
            //
            // Note that `@mut $0` from `lhs` and `@shd T1` frrom `rhs` are discarded, because
            // they don't have a matching type in the opposite union.

            for l in result.flatMap({ $0.0.unqualified is TypeVariable ? $0.0 : nil }) {
                let qualified = QualifiedType(
                    type: TypeUnion(walkedL.filter { $0.qualifiers == l.qualifiers }))
                try self.unify(l, qualified)
            }

            for r in result.flatMap({ $0.1.unqualified is TypeVariable ? $0.1 : nil }) {
                let qualified = QualifiedType(
                    type: TypeUnion(walkedL.filter { $0.qualifiers == r.qualifiers }))
                try self.unify(r, qualified)
            }

        case let (union as TypeUnion, _):
            var result: [QualifiedType] = []
            for l in union {
                if let _ = try? self.unify(l, b) {
                    result.append(l)
                }
            }
            guard result.count > 0 else {
                throw CompilerError.inferenceError(file: #file, line: #line)
            }
            union.replaceContent(with: Set(result))

        case (_, _ as TypeUnion):
            try? self.unify(b, a)

        case (_ as FunctionType, _ as FunctionType):
            fatalError("TODO")

        case let (lhs as StructType, rhs as StructType):
            guard a.qualifiers == b.qualifiers
                && lhs.name == rhs.name
                && lhs.members.keys == rhs.members.keys
                else {
                    throw CompilerError.inferenceError(file: #file, line: #line)
            }
            for (key, member) in lhs.members {
                try self.unify(member, rhs.members[key]!)
            }

        default:
            throw CompilerError.inferenceError(file: #file, line: #line)
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
            return self.matches(lhs.codomain, rhs.codomain)

        case let (lhs as StructType, rhs as StructType):
            return a.qualifiers == b.qualifiers
                && lhs.name == rhs.name
                && lhs.members.keys == rhs.members.keys
                && lhs.members.forAll({ self.matches($0.value, rhs.members[$0.key]!) })

        default:
            return false
        }
    }

    public func reify(_ type: QualifiedType, memo: [(UnqualifiedType, UnqualifiedType)] = [])
        -> QualifiedType
    {
        let walked = self.walked(type)

        // Check if the unqualified type is already being reified, so we can avoid infinite
        // recursions on types that may refer themselves (e.g. structs).
        if let (_, reified) = memo.first(where: { (t, _) in t === walked.unqualified }) {
            return QualifiedType(type: reified, qualifiedBy: walked.qualifiers)
        }

        switch walked.unqualified {
        case let union as TypeUnion:
            let reifiedUnion = TypeUnion(union.map { self.reify($0, memo: memo) })
            return reifiedUnion.count > 1
                ? QualifiedType(type: reifiedUnion)
                : reifiedUnion.first(where: { _ in true })!

        case let typeName as TypeName:
            let reified = TypeFactory.makeName(
                name: typeName.name,
                type: self.reify(QualifiedType(type: typeName.type), memo: memo).unqualified)
            return QualifiedType(type: reified, qualifiedBy: walked.qualifiers)

        case let functionType as FunctionType:
            let reified = TypeFactory.makeFunction(
                placeholders: functionType.placeholders,
                domain      : functionType.domain.map({ param in
                    return (param.label, self.reify(param.type, memo: memo))
                }),
                codomain: self.reify(functionType.codomain))
            return QualifiedType(type: reified, qualifiedBy: walked.qualifiers)

        case let structType as StructType:
            let reified = StructType(name: structType.name, members: [:])
            for (name, member) in structType.members {
                reified.members[name] = self.reify(member, memo: memo + [(structType, reified)])
            }
            return QualifiedType(
                type: TypeFactory.insert(reified),
                qualifiedBy: walked.qualifiers)

        default:
            return walked
        }
    }

    // MARK: Internals

    func walked(_ t: QualifiedType) -> QualifiedType {
        // Find the unified value of the unqualified type.
        let unqualified = self.walked(t.unqualified)

        // QUESTION:
        // If `t` is a variable that gets walked to a type is an union, it is possible for the
        // latter to contain qualified types whose qualifiers don't agree. This may happen when a
        // variant of `t` has been unified with a union prior to this. We can't simply filter them
        // out to create a new union, as it would break unification (`union.replaceContent(with:)`
        // would become useless), and it is unclear if keeping them can be harmful.
        // if t.unqualified is TypeVariable, let union = unqualified as? TypeUnion {
        //     assert(union.forAll { $0.qualifiers == t.qualifiers })
        // }

        // Otherwise we return the walked qualified type.
        return QualifiedType(type: unqualified, qualifiedBy: t.qualifiers)
    }

    func walked(_ t: UnqualifiedType) -> UnqualifiedType {
        if let variable     = t as? TypeVariable,
           let unifiedValue = self.storage[variable]
        {
            return self.walked(unifiedValue)
        } else {
            return t
        }
    }

    var storage: [TypeVariable: UnqualifiedType] = [:]

}
