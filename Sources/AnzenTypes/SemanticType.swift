import Utils

public protocol SemanticType: class {

    /// Returns this type qualified with the given qualifiers.
    func qualified(by qualifiers: Set<TypeQualifier>) -> QualifiedType
    /// Returns this type qualified with the given qualifier.
    func qualified(by qualifier: TypeQualifier) -> QualifiedType

    /// Returns whether two semantic types are equal.
    ///
    /// - Note: We purposely do not require `SemanticType` to conform to `Equatable`, so that we
    ///   can create heterogeneous collections of types.
    func equals(to other: SemanticType, table: EqualityTableRef) -> Bool

}

extension SemanticType {

    public func equals(to other: SemanticType) -> Bool {
        return self.equals(to: other, table: EqualityTableRef(to: [:]))
    }

}

public func ~= (lhs: SemanticType, rhs: SemanticType) -> Bool {
    return lhs.equals(to: rhs)
}

public protocol GenericType: SemanticType {

    var placeholders: Set<TypePlaceholder> { get }

}

public struct TypePair: Hashable {

    public init(_ first: SemanticType, _ second: SemanticType) {
        self.first = first
        self.second = second
    }

    public let first : SemanticType
    public let second: SemanticType

    public var hashValue: Int {
        return 0
    }

    public static func == (lhs: TypePair, rhs: TypePair) -> Bool {
        return lhs.first  === rhs.first && lhs.second === rhs.second
            || lhs.second === rhs.first && lhs.first  === rhs.second
    }

}

public typealias EqualityTableRef = Reference<[TypePair: Bool]>
