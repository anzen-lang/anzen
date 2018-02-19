public protocol SemanticType {

    /// Indicates whether or not the type is generic.
    var isGeneric: Bool { get }

}

public enum TypeQualifier {

    case cst
    case mut

}

public struct QualifiedType {

    public init(type: SemanticType, qualifiedBy qualifier: TypeQualifier) {
        self.type      = type
        self.qualifier = qualifier
    }

    public let type     : SemanticType
    public let qualifier: TypeQualifier

}
