public struct TypeAlias: SemanticType {

    public init(name: String, aliasing type: SemanticType) {
        self.name = name
        self.type = (type as? TypeAlias)?.type ?? type
    }

    public let name: String
    public var type: SemanticType

    public func equals(to other: SemanticType) -> Bool {
        guard let rhs = other as? TypeAlias else { return false }
        return self.type.equals(to: rhs.type)
    }

}
