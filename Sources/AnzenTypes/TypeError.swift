public struct TypeError: SemanticType {

    public init() {}

    public func equals(to other: SemanticType) -> Bool {
        return other is TypeError
    }

}
