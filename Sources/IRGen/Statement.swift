import AnzenAST
import LLVM

extension IRGenerator {

    /// Emits the IR for binding statements.
    public mutating func visit(_ node: BindingStmt) throws {
        // Generate the IR for the l-value.
        try visit(node.lvalue)
        guard let prop = stack.pop()! as? Property else {
            fatalError("unexpected l-value")
        }

        // Generate the IR for the r-value and bind it to the property.
        try visit(node.rvalue)
        let val = stack.pop()!
        prop.bind(to: val, by: node.op)

        // If the r-value is the result of a call expression, it should be released.
        (val as? CallResult)?.managedValue?.release()
    }

    /// Emits the IR for return statements.
    public mutating func visit(_ node: ReturnStmt) throws {
        guard let prop = returnProps.top else {
            fatalError("unexpected return value")
        }

        // Generate the IR for the return value and bind it to the property.
        try visit(node.value!)
        let val = stack.pop()!
        switch node.bindingOp {
        case .none, .copy?: prop.bindByCopy(to: val)
        case .ref?        : prop.bindByReference(to: val)
        case .move?       : prop.bindByMove(to: val)
        }

        // If the r-value is the result of a call expression, it should be released.
        (val as? CallResult)?.managedValue?.release()
    }

}
