public class StructType: GenericType, SemanticType {

    public init(
        name        : String,
        placeholders: Set<TypePlaceholder> = [],
        properties  : [String: QualifiedType] = [:],
        methods     : [String: [SemanticType]] = [:])
    {
        self.name         = name
        self.placeholders = placeholders
        self.properties   = properties
        self.methods      = methods
    }

    public init(
        name        : String,
        placeholders: Set<String>,
        properties  : [String: QualifiedType] = [:],
        methods     : [String: [SemanticType]] = [:])
    {
        self.name         = name
        self.placeholders = Set(placeholders.map(TypePlaceholder.init))
        self.properties   = properties
        self.methods      = methods
    }

    public let name        : String
    public let placeholders: Set<TypePlaceholder>
    public var properties  : [String: QualifiedType]
    public var methods     : [String: [SemanticType]]

    public func equals(to other: SemanticType, table: EqualityTableRef) -> Bool {
        if self === other {
            return true
        }

        let pair = TypePair(self, other)
        if let result = table.wrapped[pair] {
            return result
        }

        // This prevents infinite recursion.
        table.wrapped[pair] = true

        guard let rhs = other as? StructType,
            self.name             == rhs.name,
            self.placeholders     == rhs.placeholders,
            self.properties.count == rhs.properties.count,
            self.methods.count    == rhs.methods.count
        else {
            table.wrapped[pair] = false
            return false
        }

        for (name, left) in self.properties {
            guard let right = rhs.properties[name],
                left.equals(to: right, table: table)
            else {
                table.wrapped[pair] = false
                return false
            }
        }

        for (name, left) in self.methods {
            guard var right = rhs.methods[name] else {
                table.wrapped[pair] = false
                return false
            }

            for fnl in left {
                guard let i = right.index(where: { fnl.equals(to: $0, table: table) }) else {
                    table.wrapped[pair] = false
                    return false
                }
                right.remove(at: i)
            }
        }

        return true
    }

}
