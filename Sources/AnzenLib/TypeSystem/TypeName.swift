public class TypeName: UnqualifiedType {

    init(name: String, type: UnqualifiedType) {
        self.name = name
        self.type = type
    }

    public let name: String
    public var type: UnqualifiedType

    public var isGeneric: Bool {
        return self.type.isGeneric
    }

}

// MARK: Internals

extension TypeName: Equatable {

    public static func ==(lhs: TypeName, rhs: TypeName) -> Bool {
        return (lhs.name == rhs.name)
            && (lhs.type === rhs.type)
    }

}
