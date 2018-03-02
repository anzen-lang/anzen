public protocol SemanticType {

    /// Returns this type qualified with the given qualifiers.
    func qualified(by qualifiers: Set<TypeQualifier>) -> QualifiedType
    /// Returns this type qualified with the given qualifier.
    func qualified(by qualifier: TypeQualifier) -> QualifiedType

    /// Returns whether two semantic types are equal.
    ///
    /// - Note: We purposely do not require `SemanticType` to conform to `Equatable`, so that we
    /// can create heterogeneous collections of types.
    func equals(to other: SemanticType) -> Bool

}

extension SemanticType {

    public func qualified(by qualifiers: Set<TypeQualifier>) -> QualifiedType {
        return QualifiedType(type: self, qualifiedBy: qualifiers)
    }

    public func qualified(by qualifier: TypeQualifier) -> QualifiedType {
        return QualifiedType(type: self, qualifiedBy: [qualifier])
    }

}

public protocol GenericType: SemanticType {

    var placeholders: Set<TypePlaceholder> { get }

}
