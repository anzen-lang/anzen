public struct Symbol {

    public init(name: String) {
        self.name = name
    }

    public var name: String
    public var type: Type? = nil
    public var node: Node? = nil

}

/// A mapping from names to symbols.
///
/// This collection stores the symbols that are declared within a scope (e.g. a function scope).
/// It is a mapping `String -> [Symbol]`, as a symbol names may be overloaded.
public class Scope {

    public init(name: String, parent: Scope? = nil) {
        self.name   = name
        self.parent = parent
    }

    weak var parent  : Scope?

    let name    : String
    var children: [Scope] = []


    fileprivate static var nextID = 0

}
