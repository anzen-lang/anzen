/// Placeholder for generic types.
///
/// A generic type describes a family of types that conform to each other, modulo the respective
/// binding of their type placholders. More formally, a plachoder can be seen as a type variable
/// bound to an universal quantifier. For instance, the type `<T>(x: T) -> T` describes the set
/// of functions from a type `T` to the same type `T` (e.g. the identity).
public class TypePlaceholder: SemanticType {

    public init(named name: String) {
        self.name = name
    }

    public let name: String

    public func equals(to other: SemanticType, table: EqualityTableRef) -> Bool {
        return self === other
    }

}

// MARK: Internals

extension TypePlaceholder: Hashable {

    public var hashValue: Int {
        return self.name.hashValue
    }

    public static func == (lhs: TypePlaceholder, rhs: TypePlaceholder) -> Bool {
        return lhs === rhs
    }

}
