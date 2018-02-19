public struct TypeAlias: SemanticType {

    init(name: String, aliasing type: SemanticType) {
        self.name = name
        self.type = (type as? TypeAlias)?.type ?? type
    }

    public let name: String
    public var type: SemanticType

    public var isGeneric: Bool {
        return self.type.isGeneric
    }

}
