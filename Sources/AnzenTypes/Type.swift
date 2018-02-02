public protocol SemanticType {

    var isGeneric: Bool { get }

}

public struct QualifiedType: Hashable, SemanticType {

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

}
