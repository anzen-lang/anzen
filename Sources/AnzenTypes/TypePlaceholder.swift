public struct TypePlaceholder: SemanticType {

    public init(named name: String) {
        self.name = name
    }

    public let isGeneric = true
    public let name: String

}

// MARK: Internals

extension TypePlaceholder: Hashable {

    public var hashValue: Int {
        return self.name.hashValue
    }

    public static func ==(lhs: TypePlaceholder, rhs: TypePlaceholder) -> Bool {
        return lhs.name == rhs.name
    }

}
