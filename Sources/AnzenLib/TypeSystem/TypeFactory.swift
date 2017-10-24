struct TypeFactory {

    public static func makeName(name: String, type: UnqualifiedType) -> TypeName {
        let newType = TypeName(name: name, type: type)
        if let existing = TypeFactory.findSame(as: newType) {
            return existing
        }
        TypeFactory.types.append(WeakReference(newType))
        return newType
    }

    public static func makeFunction(
        domain: [(label: String?, type: QualifiedType)], codomain: QualifiedType?) -> FunctionType
    {
        let newType = FunctionType(domain: domain, codomain: codomain)
        if let existing = TypeFactory.findSame(as: newType) {
            return existing
        }
        TypeFactory.types.append(WeakReference(newType))
        return newType
    }

    public static func makeStruct(
        name: String, members: [String: QualifiedType] = [:]) -> StructType
    {
        let newType = StructType(name: name, members: members)
        if let existing = TypeFactory.findSame(as: newType) {
            return existing
        }
        TypeFactory.types.append(WeakReference(newType))
        return newType
    }

    // Mark: Internals

    fileprivate static func findSame<T>(as newType: T) -> T?
        where T: UnqualifiedType & Equatable
    {
        // Check if `newType` already exists in the factory's store.
        var i = 0
        while i < TypeFactory.types.count - 1 {
            // Remove types that aren't used anymore.
            guard TypeFactory.types[i].value != nil else {
                TypeFactory.types.remove(at: i)
                continue
            }

            // Check for a match.
            if let candidate = TypeFactory.types[i].value as? T, candidate == newType {
                return candidate
            }

            i += 1
        }

        // `newType` has no equivalence in the factory's store.
        return nil
    }

    fileprivate static var types: [WeakReference] = []

}

fileprivate struct WeakReference {

    init(_ value: UnqualifiedType) {
        self.value = value
    }

    weak var value: UnqualifiedType?

}
