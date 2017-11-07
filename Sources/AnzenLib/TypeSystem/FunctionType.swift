public class FunctionType: UnqualifiedType {

    init(
        placeholders: Set<String> = [],
        domain      : [(label: String?, type: QualifiedType)],
        codomain    : QualifiedType)
    {
        self.placeholders = placeholders
        self.domain       = domain
        self.codomain     = codomain
    }

    public let placeholders: Set<String>
    public let domain      : [(label: String?, type: QualifiedType)]
    public var codomain    : QualifiedType

    public var isGeneric: Bool {
        return !self.placeholders.isEmpty
    }

}

// MARK: Internals

extension FunctionType: Equatable {

    public static func ==(lhs: FunctionType, rhs: FunctionType) -> Bool {
        guard lhs.placeholders == rhs.placeholders else { return false }
        guard lhs.codomain     == rhs.codomain     else { return false }
        guard lhs.domain.count == rhs.domain.count else { return false }
        for (lparam, rparam) in zip(lhs.domain, rhs.domain) {
            guard lparam.label == rparam.label else { return false }
            guard lparam.type  == rparam.type  else { return false }
        }
        return true
    }

}

