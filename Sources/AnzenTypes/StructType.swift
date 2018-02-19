public class StructType: SemanticType {

    init(name: String, placeholders: Set<String> = [], members: [String: QualifiedType]) {
        self.name         = name
        self.placeholders = placeholders
        self.members      = members
    }

    public let name        : String
    public let placeholders: Set<String>
    public var members     : [String: QualifiedType]

    public var isGeneric: Bool {
        return self.members.values.contains(where: { $0.type.isGeneric })
    }

}

