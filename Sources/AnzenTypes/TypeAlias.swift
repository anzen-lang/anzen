public class TypeAlias: SemanticType {

    public init(name: String, aliasing type: SemanticType) {
        self.name = name
        self.type = (type as? TypeAlias)?.type ?? type
    }

    public let name: String
    public var type: SemanticType

    public func equals(to other: SemanticType, table: EqualityTableRef) -> Bool {
        if self === other {
            return true
        }

        let pair = TypePair(self, other)
        if let result = table.wrapped[pair] {
            return result
        }

        guard let rhs = other as? TypeAlias,
            self.type.equals(to: rhs.type, table: table)
            else {
                table.wrapped[pair] = false
                return false
        }

        table.wrapped[pair] = true
        return true
    }


}
