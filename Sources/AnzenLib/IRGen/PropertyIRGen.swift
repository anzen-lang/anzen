import LLVM

extension IRGenerator {

    mutating func visit(_ node: PropDecl) throws {
        if let insertBlock = self.builder.insertBlock {
            // Get the LLVM function under declaration.
            let fn = insertBlock.parent!

            // Create an alloca for the local variable, and store it as a local symbol table.
            let binding = self.createEntryBlockAlloca(
                in: fn, named: node.name, typed: node.type!)
            self.locals.last[node.name] = binding

            if let (op, value) = node.initialBinding {
                try self.visit(value)
                try self.createStore(self.stack.pop()!, op: op, to: binding)
            }
        }
        //        // Create a global variable.
        //        var property = self.builder.addGlobal(
        //            node.name, type: node.type!.irType(context: self.llvmContext)!)
        //        property.linkage = .common
        //        property.initializer = initialValue
        //        self.globals[node.name] = property
    }

}

