public struct QualifiedType {

    public init(type: SemanticType, qualifiedBy qualifiers: Set<TypeQualifier>) {
        self.type       = type
        self.qualifiers = qualifiers
    }

    public let type      : SemanticType
    public let qualifiers: Set<TypeQualifier>

}

extension QualifiedType: Equatable {

    public static func == (lhs: QualifiedType, rhs: QualifiedType) -> Bool {
        return lhs.qualifiers == rhs.qualifiers && lhs.type.equals(to: rhs.type)
    }

}

public enum TypeQualifier {

    case cst, mut

}
