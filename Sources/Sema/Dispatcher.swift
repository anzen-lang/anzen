import AnzenAST
import AnzenTypes

public struct Dispatcher: ASTVisitor, Pass {

    public let name: String = "static dispatching"

    public init() {}

    public mutating func run(on module: ModuleDecl) -> [Error] {
        do {
            try self.visit(module)
            return self.errors
        } catch {
            return [error]
        }
    }

    public func visit(_ node: Ident) throws {
        if node.symbol == nil {
            let symbols = node.scope?[node.name] ?? []
            assert(symbols.count > 0)

            for symbol in symbols {
                // Associate the node with the symbol if their type is a perfect match.
                if symbol.type.equals(to: node.type!) {
                    node.symbol = symbol
                    break
                }
            }
        }
        print(node.name)
    }

    private var errors: [Error] = []

}

// MARK: Internals

extension FunctionType {

    /// Similar to `equals(to:)` except that it doesn't take type qualifiers into account.
    fileprivate func matches(with other: SemanticType) -> Bool {
        if self === other {
            return true
        }

        let table = EqualityTableRef(to: [:])
        guard let rhs = other as? FunctionType,
            self.placeholders == rhs.placeholders,
            _matches(domain: self.domain, with: rhs.domain, table: table),
            self.codomain.type.equals(to: rhs.codomain.type, table: table)
        else {
            return false
        }

        return true
    }

}

private func _matches(
    domain lhs: [ParameterDescription],
    with   rhs: [ParameterDescription],
    table     : EqualityTableRef) -> Bool
{
    guard lhs.count == rhs.count else { return false }
    for (lp, rp) in zip(lhs, rhs) {
        guard lp.label == rp.label && lp.type.type.equals(to: rp.type.type, table: table)
            else { return false }
    }
    return true
}
