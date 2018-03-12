import AnzenAST
import LLVM

extension IRGenerator {

    /// Emits the IR of an identifier.
    public mutating func visit(_ node: Ident) throws {
        guard let prop = locals.top?[node.name] else { fatalError() }
        stack.push(prop)
    }

}
