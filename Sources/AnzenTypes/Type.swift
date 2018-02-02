public protocol AnzenType {
}

public struct QualifiedType: Hashable {

    public init(type unqualified: UnqualifiedType, qualifiedBy qualifiers: TypeQualifier = []) {
        self.qualifiers  = qualifiers
        self.unqualified = unqualified
    }

    public var qualifiers : TypeQualifier
    public var unqualified: UnqualifiedType

    public var isGeneric: Bool {
        return self.unqualified.isGeneric
    }

    public var hashValue: Int {
        // NOTE: Because we ensure unqualified types (except unions) are unique, hashing them
        // would probably be more costly than simply checking for their pointer equivalence.
        return self.qualifiers.rawValue
    }

    public static func ==(lhs: QualifiedType, rhs: QualifiedType) -> Bool {
        return (lhs.qualifiers == rhs.qualifiers)
            && (lhs.unqualified === rhs.unqualified)
    }

}

public protocol UnqualifiedType: class {

    var isGeneric: Bool { get }

}

public struct TypeQualifier: OptionSet {

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public let rawValue: Int

    public static let cst = TypeQualifier(rawValue: 1 << 0)
    public static let mut = TypeQualifier(rawValue: 1 << 1)
    public static let stk = TypeQualifier(rawValue: 1 << 2)
    public static let shd = TypeQualifier(rawValue: 1 << 3)
    public static let val = TypeQualifier(rawValue: 1 << 4)
    public static let ref = TypeQualifier(rawValue: 1 << 5)

    public static let combinations: [TypeQualifier] = [
        [.cst, .stk, .ref],
        [.mut, .stk, .ref],
        [.cst, .shd, .ref],
        [.mut, .shd, .ref],
    ]

}