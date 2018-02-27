public class TypePlaceholder: SemanticType {

    public init(named name: String) {
        self.name = name
    }

    public let name: String

    public func equals(to other: SemanticType) -> Bool {
        guard let rhs = other as? TypePlaceholder else { return false }
        return self === rhs
    }

}

// MARK: Internals

extension TypePlaceholder: Hashable {

    public var hashValue: Int {
        return self.name.hashValue
    }

    public static func == (lhs: TypePlaceholder, rhs: TypePlaceholder) -> Bool {
        return lhs === rhs
    }

}
