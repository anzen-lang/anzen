public class FunctionType: SemanticType {

    public typealias ParameterDescription = (label: String?, type: QualifiedType)

    init(
        placeholders: Set<String> = [],
        from domain : [ParameterDescription],
        to codomain : QualifiedType)
    {
        self.placeholders = placeholders
        self.domain       = domain
        self.codomain     = codomain
    }

    public let placeholders: Set<String>
    public let domain      : [ParameterDescription]
    public var codomain    : QualifiedType

    public var isGeneric: Bool {
        return !self.placeholders.isEmpty
    }

}
