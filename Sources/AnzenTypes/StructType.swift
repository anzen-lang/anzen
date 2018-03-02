public class StructType: GenericType, SemanticType {

    public init(
        name        : String,
        placeholders: Set<TypePlaceholder> = [],
        properties  : [String: QualifiedType] = [:],
        methods     : [String: [SemanticType]] = [:])
    {
        self.name         = name
        self.placeholders = placeholders
        self.properties   = properties
        self.methods      = methods
    }

    public let name        : String
    public let placeholders: Set<TypePlaceholder>
    public var properties  : [String: QualifiedType]
    public var methods     : [String: [SemanticType]]

    public func equals(to other: SemanticType) -> Bool {
        guard let rhs = other as? StructType else { return false }
        return self === rhs
    }

}
