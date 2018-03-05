public class SelfType: SemanticType {

    public init(aliasing type: SemanticType) {
        self.type = type
    }

    public let type: SemanticType

    public func equals(to other: SemanticType, table: EqualityTableRef) -> Bool {
        if self === other {
            return true
        }

        let pair = TypePair(self, other)
        if let result = table.wrapped[pair] {
            return result
        }

        guard let rhs = other as? SelfType,
            self.type.equals(to: rhs.type, table: table)
        else {
            table.wrapped[pair] = false
            return false
        }

        table.wrapped[pair] = true
        return true
    }

}
