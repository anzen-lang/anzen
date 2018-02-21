public struct TypeVariable: SemanticType {

    public init() {
        self.id = TypeVariable.nextID
        TypeVariable.nextID += 1
    }

    // NOTE: We chose to always consider type variables non-generic. The consequence is that
    // whenever we visit a generic type that has yet to be specialized, we have to type the
    // expression that uses it with another fresh variable. Another approach would be to allow
    // type variables to hold a specialization list, so as to represent "some type specialized as
    // such". This would reduce the number of variables we have to create, but would also make
    // matching and unification harder.
    public let isGeneric = false

    public func equals(to other: SemanticType) -> Bool {
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

    public static func ==(lhs: TypeVariable, rhs: TypeVariable) -> Bool {
        return lhs.id == rhs.id
    }

}
