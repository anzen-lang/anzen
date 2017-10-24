struct Substitution {

    func unify(_ t: QualifiedType, _ u: QualifiedType) throws {
    }

    // MARK: Internals

    private func walked(_ t: QualifiedType) -> QualifiedType {
        // Find the unified value of the unqualified type.
        let unqualified = self.walked(t.unqualified)

        // If the unqualified type is an union, we keep only the candidates whose qualifiers match
        // that of the given qualified type.
        if let union = unqualified as? TypeUnion {
            return QualifiedType(
                type       : TypeUnion(union.filter { $0.qualifiers == t.qualifiers }),
                qualifiedBy: t.qualifiers)
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
