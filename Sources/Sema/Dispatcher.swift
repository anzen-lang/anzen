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

    public mutating func visit(_ node: Ident) throws {
        if node.symbol == nil {
            let symbols = node.scope?[node.name] ?? []
            assert(symbols.count > 0)

            var perfectMatch: Symbol? = nil
            var otherMatches: [Symbol] = []

            for symbol in symbols {
                // Functions should be compared without any regards for the qualifiers of their
                // domain/codomain, as those aren't inferred during type solving.
                if let fn = symbol.type as? FunctionType {
                    if fn.matches(with: node.type!) {
                        perfectMatch = symbol
                        break
                    }
                }
                if symbol.type.equals(to: node.type!) {
                    perfectMatch = symbol
                    break
                }

                if let specialized = symbol.type.specialized(with: node.type!) {
                    if specialized.equals(to: node.type!) {
                        otherMatches.append(symbol)
                    }
                }
            }

            // Perfect matches are prioritized over specialized matches.
            if otherMatches.count > 1 {
                self.errors.append(
                    AmbiguousType(
                        expr: node.name,
                        candidates: otherMatches.map({ $0.type }),
                        location: node.location))
            } else {
                node.symbol = perfectMatch ?? otherMatches.first
                assert(node.symbol != nil)
            }
        }
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
