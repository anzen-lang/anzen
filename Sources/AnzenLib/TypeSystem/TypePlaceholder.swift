public class TypePlaceholder: UnqualifiedType {

    init(named name: String) {
        self.name = name
    }

    public let isGeneric = true
    public let name: String

}

// MARK: Internals

extension TypePlaceholder: Equatable {

    public static func ==(lhs: TypePlaceholder, rhs: TypePlaceholder) -> Bool {
        return lhs === rhs
    }

}

extension TypePlaceholder: Hashable {

    public var hashValue: Int {
        // NOTE: That's the hash value of the `self` pointer.
        return Unmanaged<TypePlaceholder>.passUnretained(self).toOpaque().hashValue
    }

}
