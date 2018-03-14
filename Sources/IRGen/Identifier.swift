import AnzenAST
import LLVM

extension IRGenerator {

    /// Emits the IR of an identifier.
    public mutating func visit(_ node: Ident) throws {
        guard let prop = symbolMaps.top?[node.symbol!] ?? hoistedSymbolMap[node.symbol!]
            else { fatalError("unbound identifier") }
        stack.push(prop)
    }

}
