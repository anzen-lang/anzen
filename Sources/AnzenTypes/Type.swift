public protocol SemanticType {

    /// Indicates whether or not the type is generic.
    var isGeneric: Bool { get }

    /// Returns this type qualified with the given qualifiers.
    func qualified(by qualifiers: Set<TypeQualifier>) -> QualifiedType
    /// Returns this type qualified with the given qualifier.
    func qualified(by qualifier: TypeQualifier) -> QualifiedType

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

public enum TypeQualifier {

    case cst
    case mut

}

public struct QualifiedType {

    public init(type: SemanticType, qualifiedBy qualifiers: Set<TypeQualifier>) {
        self.type       = type
        self.qualifiers = qualifiers
    }

    public let type      : SemanticType
    public let qualifiers: Set<TypeQualifier>

}

extension QualifiedType: Equatable {

    public static func ==(lhs: QualifiedType, rhs: QualifiedType) -> Bool {
        return lhs.qualifiers == rhs.qualifiers && lhs.type.equals(to: rhs.type)
    }

}

