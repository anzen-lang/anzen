public enum FunctionAttribute {

    case mutable
    case `static`

}

public typealias ParameterDescription = (label: String?, type: QualifiedType)

public class FunctionType: GenericType, SemanticType {

    public init(
        placeholders: Set<TypePlaceholder> = [],
        from domain : [ParameterDescription],
        to codomain : QualifiedType)
    {
        self.placeholders = placeholders
        self.domain       = domain
        self.codomain     = codomain
    }

    public let placeholders: Set<TypePlaceholder>
    public let domain      : [ParameterDescription]
    public let codomain    : QualifiedType

    public func equals(to other: SemanticType, table: EqualityTableRef) -> Bool {
        if self === other {
            return true
        }

        let pair = TypePair(self, other)
        if let result = table.wrapped[pair] {
            return result
        }

        guard let rhs = other as? FunctionType,
            self.placeholders == rhs.placeholders,
            _equals(domain: self.domain, to: rhs.domain, table: table),
            self.codomain.equals(to: rhs.codomain, table: table)
        else {
            table.wrapped[pair] = false
            return false
        }

        table.wrapped[pair] = true
        return true
    }

}

// MARK: Internals

private func _equals(
    domain lhs: [ParameterDescription],
    to     rhs: [ParameterDescription],
    table     : EqualityTableRef) -> Bool
{
    guard lhs.count == rhs.count else { return false }
    for (lp, rp) in zip(lhs, rhs) {
        guard lp.label == rp.label && lp.type.equals(to: rp.type, table: table)
            else { return false }
    }
    return true
}
