import AnzenAST
import AnzenTypes
import LLVM

protocol Property {

    var ref: IRValue { get }
    var val: IRValue { get }

}

struct LocalProperty: Property {

    init(
        function    : Function,
        semanticType: SemanticType,
        generator   : IRGenerator,
        name        : String? = nil)
    {
        // Create an alloca in the function for an instance of `managed_object`.
        self.pointer = generator.buildEntryAlloca(
            in: function, typed: generator.managed_object, named: name)

        // Store other properties.
        self.semanticType = semanticType
        self.llvmType = semanticType.llvmType(context: generator.context)
        self.builder = generator.builder

        // Initialize the memory for the property's value.
        let llvmType = semanticType.llvmType(context: generator.context)
        let size     = generator.layout.sizeOfTypeInBits(llvmType) / 8
        generator.builder.buildStore(
            generator.builder.buildCall(generator.malloc, args: [IntType.int64.constant(size)]),
            to: generator.builder.buildStructGEP(self.pointer, index: 0))

        // Initialize the reference counter to 1.
        generator.builder.buildStore(
            IntType.int64.constant(1),
            to: generator.builder.buildStructGEP(self.pointer, index: 1))
    }

    /// A pointer to the property's allocation.
    let pointer: IRValue

    /// The (Anzen) semantic type of the property.
    let semanticType: SemanticType

    /// The (LLVM) IR type of the property.
    let llvmType: IRType

    /// A reference to the LLVM module builder (to emit IR for load instructions).
    unowned let builder: IRBuilder

    var ref: IRValue {
        let fieldPtr = self.builder.buildStructGEP(self.pointer, index: 0)
        let field    = self.builder.buildLoad(fieldPtr)
        return self.builder.buildBitCast(field, type: self.llvmType)
    }

    var val: IRValue {
        return self.builder.buildLoad(self.ref)
    }

}

extension IRGenerator {

    public mutating func visit(_ node: PropDecl) throws {
        if let function = self.builder.insertBlock?.parent {
            try self.createLocal(node, in: function)
        } else {
            fatalError("Gloabl variables aren't supported")
        }
    }

    private mutating func createLocal(_ node: PropDecl, in function: Function) throws {
        // Create the local property.
        let property = LocalProperty(
            function: function, semanticType: node.type!, generator: self, name: node.name)
        self.locals.top?[node.name] = property

        // Generate the IR for optional the initial value.
        if let (op, value) = node.initialBinding {
            try self.buildBinding(to: property, op: op, valueOf: value)
        }
    }

}
