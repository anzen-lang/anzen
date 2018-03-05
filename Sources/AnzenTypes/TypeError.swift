public class TypeError: SemanticType {

    public init() {}

    public func equals(to other: SemanticType, table: EqualityTableRef) -> Bool {
        return other is TypeError
    }

}
