public class StructType: UnqualifiedType {

    init(name: String, members: [String: QualifiedType]) {
        self.name    = name
        self.members = members
    }

    public let name   : String
    public var members: [String: QualifiedType]

    public var isGeneric: Bool { return false }

}

// MARK: Internals

extension StructType: Equatable {

    public static func ==(lhs: StructType, rhs: StructType) -> Bool {
        guard lhs.name == rhs.name else { return false }
        guard lhs.members.count == rhs.members.count else { return false }

        // Recursively check for members equality.
        for (name, ltype) in lhs.members {
            guard let rtype = rhs.members[name] else { return false }
            guard ltype == rtype else { return false }
        }

        return true
    }

}
