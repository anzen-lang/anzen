import AnzenAST
import AnzenTypes
import LLVM

/// The protocol for local and global properties.
protocol Property: Emittable {

    func bind(to value: Emittable, by bindingPolicy: BindingPolicy)

}

/// An enumeration of the possible property binding policies.
enum BindingPolicy {

    case copy, reference, move

}

/// A local property.
struct LocalProperty: Property {

    init(function: Function, anzenType: SemanticType, generator: IRGenerator, name: String) {
        // Create an alloca in the function for an instance of `managed_object`.
        self.pointer = generator.buildEntryAlloca(
            in: function, typed: generator.managed_object, named: name)

        // Store other properties.
        self.anzenType = anzenType
        self.llvmType = anzenType.llvmType(context: generator.context)
        self.builder = generator.builder

        // Initialize the memory for the property's value.
        let llvmType = anzenType.llvmType(context: generator.context)
        let size = generator.layout.sizeOfTypeInBits(llvmType) / 8
        generator.builder.buildStore(
            generator.builder.buildCall(generator.malloc, args: [IntType.int64.constant(size)]),
            to: generator.builder.buildStructGEP(self.pointer, index: 0))

        // Initialize the reference counter to 1.
        generator.builder.buildStore(
            IntType.int64.constant(1),
            to: generator.builder.buildStructGEP(self.pointer, index: 1))
    }

    func bind(to value: Emittable, by bindingPolicy: BindingPolicy) {
        guard bindingPolicy == .copy else { fatalError() }

        // Binding a property by copy doesn't update any refcounter.
        self.builder.buildStore(value.val, to: self.ref!)
    }

    /// A pointer to the property's allocation.
    let pointer: IRValue

    /// The Anzen semantic type of the property.
    let anzenType: SemanticType

    /// The LLVM IR type of the property.
    let llvmType: IRType

    /// A reference to the LLVM module builder (to emit IR for load instructions).
    unowned let builder: IRBuilder

    /// The LLVM IR value representing a reference (pointer) to the property.
    var ref: IRValue? {
        let fieldPtr = self.builder.buildStructGEP(self.pointer, index: 0)
        let field = self.builder.buildLoad(fieldPtr)
        return self.builder.buildBitCast(field, type: self.llvmType)
    }

    /// The LLVM IR value representing the value of the property.
    var val: IRValue {
        return self.builder.buildLoad(self.ref!)
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
            function: function, anzenType: node.type!, generator: self, name: node.name)
        self.locals.top?[node.name] = property

        // Generate the IR for optional the initial value.
        if let (op, value) = node.initialBinding {
            try self.buildBinding(to: property, op: op, valueOf: value)
        }
    }

}
