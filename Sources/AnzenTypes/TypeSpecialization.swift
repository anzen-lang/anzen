public class TypeSpecialization: SemanticType {

    public init(
        specializing type   : GenericType,
        with specializations: [TypePlaceholder: SemanticType])
    {
        self.genericType     = type
        self.specializations = specializations
    }

    public func equals(to other: SemanticType, table: EqualityTableRef) -> Bool {
        if self === other {
            return true
        }

        let pair = TypePair(self, other)
        if let result = table.wrapped[pair] {
            return result
        }

        guard let rhs = other as? TypeSpecialization,
            self.genericType.equals(to: rhs.genericType, table: table),
            _equals(args: self.specializations, to: rhs.specializations, table: table)
        else {
            table.wrapped[pair] = false
            return false
        }

        table.wrapped[pair] = true
        return true
    }


    public let genericType    : GenericType
    public let specializations: [TypePlaceholder: SemanticType]

}

// MARK: Internal

private func _equals(
    args  lhs: [TypePlaceholder: SemanticType],
    to    rhs: [TypePlaceholder: SemanticType],
    table    : EqualityTableRef) -> Bool
{
    guard lhs.count == rhs.count else { return false }
    for (key, lvalue) in lhs {
        guard let rvalue = rhs[key]                   else { return false }
        guard lvalue.equals(to: rvalue, table: table) else { return false }
    }
    return true
}
