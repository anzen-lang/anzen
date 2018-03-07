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
class LocalProperty: Property {

    init(function: Function, anzenType: SemanticType, generator: IRGenerator, name: String) {
        // Store the property's type.
        self.anzenType = anzenType
        self.llvmType = anzenType.llvmType(context: generator.context)

        // Store the IR generation objects.
        self.builder = generator.builder
        self.runtime = generator.runtime

        // Create an alloca in the function for an instance of `gc_object`.
        self.pointer = generator.builder.buildEntryAlloca(
            in: function, type: generator.runtime.gc_object, name: name)
    }

    func bind(to value: Emittable, by bindingPolicy: BindingPolicy) {
        switch bindingPolicy {
        case .copy:
            // If the property isn't bound to any value, we need to initialize the `gc_object`.
            if !isBounded {
                let size = builder.module.dataLayout.abiSize(of: llvmType)
                _ = builder.buildCall(
                    runtime.gc_object_init,
                    args: [
                        pointer,
                        NativeInt.constant(size),
                        (Runtime.destructorType*).null(),
                    ])
                isBounded = true
            }

            // Copying a property doesn't modify its ref-counter, so we can emit a single store
            // instruction, no matter what the rvalue is.
            builder.buildStore(value.val, to: ref!)

        case .reference:
            guard let prop = value as? LocalProperty else {
                fatalError("Cannot emit reference binding to non-local property.")
            }

            // Binding a property by reference decrements own its ref-counter.
            if isBounded { emitRelease() }

            for i in 0 ... 2 {
                builder.buildStore(
                    builder.buildLoad(builder.buildStructGEP(prop.pointer, index: i)),
                    to: builder.buildStructGEP(pointer, index: i))
            }
            isBounded = true
            emitRetain()

        case .move:
            // Binding a property by move decrements its own ref-counter.
            if isBounded { emitRelease() }

            // If the r-value isn't a `gc_object`, a move binding is equivalent to a copy.
            guard let prop = value as? LocalProperty else {
                self.bind(to: value, by: .copy)
                return
            }

            // If the r-value is a gc_object, we "steal" all its pointers and leave it unbounded.
            for i in 0 ... 2 {
                builder.buildStore(
                    builder.buildLoad(builder.buildStructGEP(prop.pointer, index: i)),
                    to: builder.buildStructGEP(pointer, index: i))
            }
            prop.isBounded = false
        }
    }

    func emitRetain() {
        assert(self.isBounded)
        _ = self.builder.buildCall(self.runtime.gc_object_retain, args: [ self.pointer ])
    }

    func emitRelease() {
        assert(self.isBounded)
        _ = self.builder.buildCall(self.runtime.gc_object_release, args: [ self.pointer ])
    }

    /// Whether or not the property is bound to a value.
    var isBounded: Bool = false
    /// A pointer to the property's allocation.
    let pointer: IRValue
    /// The Anzen semantic type of the property.
    let anzenType: SemanticType
    /// The LLVM IR type of the property.
    let llvmType: IRType

    /// A reference to the IR builder.
    unowned let builder: IRBuilder
    /// A copy of the runtime wrapper.
    let runtime: Runtime

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

    public mutating func visit(_ node: BindingStmt) throws {
        // Generate the IR for the l-value.
        try self.visit(node.lvalue)

        switch self.stack.pop()! {
        case let prop as LocalProperty:
            try self.buildBinding(to: prop, op: node.op, valueOf: node.rvalue)
        default:
            fatalError("unexpected l-value")
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
