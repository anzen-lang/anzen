public struct SelfType: SemanticType {

    public init(aliasing type: SemanticType) {
        self.type = type
    }

    public let type: SemanticType

    public func equals(to other: SemanticType) -> Bool {
        guard let rhs = other as? SelfType else { return false }
        return self.type.equals(to: rhs.type)
    }

}
