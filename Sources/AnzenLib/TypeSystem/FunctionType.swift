public class FunctionType: UnqualifiedType {

    init(
        domain  : [(label: String?, type: QualifiedType)],
        codomain: QualifiedType)
    {
        self.domain   = domain
        self.codomain = codomain
    }

    public let domain  : [(label: String?, type: QualifiedType)]
    public var codomain: QualifiedType

    public var isGeneric: Bool { return false }

}

// MARK: Internals

extension FunctionType: Equatable {

    public static func ==(lhs: FunctionType, rhs: FunctionType) -> Bool {
        guard lhs.domain.count == rhs.domain.count else { return false }
        for (lparam, rparam) in zip(lhs.domain, rhs.domain) {
            guard lparam.label == rparam.label else { return false }
            guard lparam.type  == rparam.type  else { return false }
        }
        guard lhs.codomain == rhs.codomain else { return false }
        return true
    }

}

