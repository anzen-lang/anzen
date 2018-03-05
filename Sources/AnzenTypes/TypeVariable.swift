public class TypeVariable: SemanticType {

    public init() {
        self.id = TypeVariable.nextID
        TypeVariable.nextID += 1
    }

    public func equals(to other: SemanticType, table: EqualityTableRef) -> Bool {
        guard let rhs = other as? TypeVariable else { return false }
        return self.id == rhs.id
    }

    // MARK: Internals

    var id: Int
    private static var nextID = 0

}

extension TypeVariable: Hashable {

    public var hashValue: Int {
        return self.id
    }

    public static func == (lhs: TypeVariable, rhs: TypeVariable) -> Bool {
        return lhs.id == rhs.id
    }

}
