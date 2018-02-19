import AnzenTypes

/// A named symbol.
public class Symbol {

    public init(name: String, type: SemanticType? = nil, overloadable: Bool = false) {
        self.name           = name
        self.type           = type ?? TypeVariable()
        self.isOverloadable = overloadable
    }

    public let name: String
    public var type: SemanticType

    /// Let function symbols be marked overloadable.
    public let isOverloadable: Bool

}

/// A mapping from names to symbols.
///
/// This collection stores the symbols that are declared within a scope (e.g. a function scope).
/// It is a mapping `String -> [Symbol]`, as a symbol names may be overloaded.
public class Scope {

    public init(name: String? = nil, parent: Scope? = nil) {
        // Create a unique ID for the scope.
        self.id = Scope.nextID
        Scope.nextID += 1

        self.name   = name
        self.parent = parent
    }

    /// Returns whether or not a symbol with the given name exists in this scope.
    public func defines(name: String) -> Bool {
        if let symbols = self.symbols[name] {
            return !symbols.isEmpty
        }
        return false
    }

    /// Adds a symbol to this scope.
    public func add(symbol: Symbol) {
        precondition(self[symbol.name].forAll({ $0.isOverloadable }))
        self[symbol.name].append(symbol)
    }

    /// Returns the first scope in the hierarchy for which a symbol with the given name exists.
    public func findScopeDefining(name: String) -> Scope? {
        if let _ = self.symbols[name] {
            return self
        } else if let parent = self.parent {
            return parent.findScopeDefining(name: name)
        } else {
            return nil
        }
    }

    public weak var parent: Scope?

    public let id      : Int
    public let name    : String?
    public var children: [Scope] = []
    public var symbols : [String: [Symbol]] = [:]

    fileprivate static var nextID = 0

}

extension Scope: Sequence {

    public typealias Index = (Dictionary<String, [Symbol]>.Index, Int)

    public func makeIterator() -> AnyIterator<(name: String, symbol: Symbol)> {
        var index = self.startIndex

        return AnyIterator {
            guard index.0 != self.symbols.endIndex else { return nil }

            // Store a temporary result.
            let result = self[index]

            // Advance the iterator.
            index = self.index(after: index)

            // Return the element.
            return result
        }
    }

    public subscript(index: Index) -> (name: String, symbol: Symbol) {
        return (
            name  : self.symbols[index.0].key,
            symbol: self.symbols[index.0].value[index.1])
    }

    public subscript(name: String) -> [Symbol] {
        get {
            return self.symbols[name] ?? []
        }

        set {
            self.symbols[name] = newValue
        }
    }

    public func index(after i: Index) -> Index {
        var (nameIndex, symbolIndex) = i
        if symbolIndex == (self.symbols[nameIndex].value.count - 1) {
            nameIndex   = self.symbols.index(after: nameIndex)
            symbolIndex = 0
        } else {
            symbolIndex += 1
        }
        return (nameIndex, symbolIndex)
    }

    public var startIndex: Index {
        return (self.symbols.startIndex, 0)
    }

    public var endIndex: Index {
        return (self.symbols.endIndex, 0)
    }

}

extension Scope: Hashable {

    public var hashValue: Int {
        return self.id
    }

    public static func ==(lhs: Scope, rhs: Scope) -> Bool {
        return lhs.id == rhs.id
    }

}

extension Scope: CustomStringConvertible {

    public var description: String {
        if let parent = self.parent {
            return "\(parent).\(self.name ?? self.id.description)"
        }
        return self.name ?? self.id.description
    }
}
