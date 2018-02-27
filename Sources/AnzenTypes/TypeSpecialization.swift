public struct TypeSpecialization: SemanticType {

    public init(
        specializing type   : GenericType,
        with specializations: [TypePlaceholder: SemanticType])
    {
        self.genericType     = type
        self.specializations = specializations
    }

    public func equals(to other: SemanticType) -> Bool {
        guard let rhs = other as? TypeSpecialization else { return false }
        return self.genericType.equals(to: rhs.genericType)
            && self.specializations == rhs.specializations
    }

    public let genericType    : GenericType
    public let specializations: [TypePlaceholder: SemanticType]

}

fileprivate extension Dictionary where Key == TypePlaceholder, Value == SemanticType {

    static func == (lhs: Dictionary, rhs: Dictionary) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (key, lvalue) in lhs {
            guard let rvalue = rhs[key]     else { return false }
            guard lvalue.equals(to: rvalue) else { return false }
        }
        return true
    }

}
