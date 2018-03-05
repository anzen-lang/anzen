import AnzenAST
import LLVM

extension IRGenerator {

    public mutating func visit(_ node: Ident) throws {
        guard let property = self.locals.top?[node.name] else { fatalError() }
        self.stack.push(property)
    }

}
