public final class TypeUnion: UnqualifiedType, ExpressibleByArrayLiteral {

    public init() {
        self.types = []
    }

    public init(_ other: TypeUnion) {
        self.types = other.types
    }

    public init<S: Sequence>(_ sequence: S)
        where S.Iterator.Element == QualifiedType
    {
        self.types = Set(sequence)
        assert(!self.types.contains { $0.unqualified is TypeUnion })
    }

    public convenience init(arrayLiteral elements: QualifiedType...) {
        self.init(elements)
    }

    public var isGeneric: Bool {
        return self.types.contains { $0.isGeneric }
    }

    @discardableResult
    public func insert(_ newMember: QualifiedType)
        -> (inserted: Bool, memberAfterInsert: QualifiedType)
    {
        assert(!(newMember.unqualified is TypeUnion))
        return self.types.insert(newMember)
    }

    public func union(_ other: TypeUnion) -> TypeUnion {
        let result = TypeUnion()
        result.types = self.types.union(other.types)
        return result
    }

    public func formUnion(_ other: TypeUnion) {
        self.types.formUnion(other.types)
    }

    public func intersection(_ other: TypeUnion) -> TypeUnion {
        let result = TypeUnion()
        result.types = self.types.intersection(other.types)
        return result
    }

    public func formIntersection(_ other: TypeUnion) {
        self.types.formIntersection(other.types)
    }

    public func replaceContent(with content: Set<QualifiedType>) {
        self.types = content
        assert(!self.types.contains { $0.unqualified is TypeUnion })
    }

    public var count: Int {
        return self.types.count
    }

    public static func flattening<S: Sequence>(_ sequence: S) -> TypeUnion
        where S.Iterator.Element == QualifiedType
    {
        var types = Set<QualifiedType>()
        for t in sequence {
            if let union = t.unqualified as? TypeUnion {
                types.formUnion(union)
            } else {
                types.insert(t)
            }
        }
        return TypeUnion(types)
    }

    // MARK: Internals

    fileprivate var types: Set<QualifiedType>

}

extension TypeUnion: Sequence {

    public func makeIterator() -> Set<QualifiedType>.Iterator {
        return self.types.makeIterator()
    }

}

extension TypeUnion: Equatable {

    public static func ==(lhs: TypeUnion, rhs: TypeUnion) -> Bool {
        return lhs.types == rhs.types
    }

}
