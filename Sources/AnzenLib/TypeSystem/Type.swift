public struct QualifiedType: Hashable {

    public var qualifiers     : TypeQualifier
    public var unqualifiedType: UnqualifiedType

    public var isGeneric: Bool {
        return self.unqualifiedType.isGeneric
    }

    public var hashValue: Int {
        // NOTE: Because we ensure unqualified types (except unions) are unique, hashing them
        // would probably be more costly than simply checking for their pointer equivalence.
        return self.qualifiers.rawValue
    }

    public static func ==(lhs: QualifiedType, rhs: QualifiedType) -> Bool {
        return (lhs.qualifiers == rhs.qualifiers)
            && (lhs.unqualifiedType === rhs.unqualifiedType)
    }

}

public protocol UnqualifiedType: class {

    var isGeneric: Bool { get }

}

public struct TypeQualifier: OptionSet, CustomStringConvertible {

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public let rawValue: Int

    static let cst = TypeQualifier(rawValue: 1 << 0)
    static let mut = TypeQualifier(rawValue: 1 << 1)
    static let stk = TypeQualifier(rawValue: 1 << 2)
    static let shd = TypeQualifier(rawValue: 1 << 3)
    static let val = TypeQualifier(rawValue: 1 << 4)
    static let ref = TypeQualifier(rawValue: 1 << 5)

    public var description: String {
        var result = [String]()
        if self.contains(.cst) { result.append("@cst") }
        if self.contains(.mut) { result.append("@mut") }
        if self.contains(.stk) { result.append("@stk") }
        if self.contains(.shd) { result.append("@shd") }
        if self.contains(.val) { result.append("@val") }
        if self.contains(.ref) { result.append("@ref") }
        return result.joined(separator: " ")
    }

}
