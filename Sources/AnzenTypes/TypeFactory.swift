struct TypeFactory {

    public static func makeName(name: String, type: UnqualifiedType) -> TypeName {
        return self.insert(TypeName(name: name, type: type))
    }

    public static func makeFunction(
        placeholders: Set<String> = [],
        domain      : [(label: String?, type: QualifiedType)],
        codomain    : QualifiedType) -> FunctionType
    {
        return self.insert(
            FunctionType(placeholders: placeholders, domain: domain, codomain: codomain))
    }

    public static func makeStruct(
        name: String, members: [String: QualifiedType] = [:]) -> StructType
    {
        return self.insert(StructType(name: name, members: members))
    }

    public static func makeVariants(of unqualifiedType: UnqualifiedType) -> QualifiedType {
        let variants = TypeQualifier.combinations
            .map { QualifiedType(type: unqualifiedType, qualifiedBy: $0) }
        return QualifiedType(type: TypeUnion(variants))
    }

    public static func makeVariants(
        of unqualifiedType: UnqualifiedType,
        withQualifiers    : (TypeQualifier) -> Bool) -> QualifiedType
    {
        let variants = TypeQualifier.combinations.filter(withQualifiers)
            .map { QualifiedType(type: unqualifiedType, qualifiedBy: $0) }
        return QualifiedType(type: TypeUnion(variants))
    }

    // Mark: Internals

    static func insert<T: UnqualifiedType & Equatable>(_ newType: T) -> T {
        if let existing = findSame(as: newType) {
            return existing
        }
        TypeFactory.types.append(WeakReference(newType))
        return newType
    }

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
