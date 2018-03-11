import AnzenAST
import AnzenTypes
import LLVM

/// The protocol for local and global properties.
protocol Property: Emittable {

    func bindByCopy(to value: Emittable)
    func bindByReference(to value: Emittable)
    func bindByMove(to value: Emittable)

}

/// A local property.
class LocalProperty: Property {

    init(anzenType: SemanticType, llvmType: IRType? = nil, builder: IRBuilder, alloca: IRValue) {
        self.anzenType = anzenType
        self.llvmType = llvmType ?? builder.buildValueType(of: anzenType)
        self.builder = builder
        self.alloca = alloca
    }

    init(in function: Function, anzenType: SemanticType, builder: IRBuilder) {
        self.anzenType = anzenType
        self.llvmType = builder.buildValueType(of: anzenType)
        self.builder = builder
        self.alloca = builder.buildEntryAlloca(in: function, type: self.llvmType*)
    }

    func bindByCopy(to value: Emittable) {
        if managedValue == nil {
            managedValue = ManagedValue.allocate(anzenType: anzenType, builder: builder)
            builder.buildStore(managedValue!.alloca, to: alloca)
        }
        managedValue!.val = value.val
    }

    func bindByReference(to value: Emittable) {
        guard let prop = value as? LocalProperty else {
            fatalError("Cannot emit reference binding to non-local property.")
        }

        // Binding a property by reference decrements its reference count.
        managedValue?.release()

        // Rebind the property.
        managedValue = prop.managedValue
        builder.buildStore(managedValue!.alloca, to: alloca)
        managedValue!.retain()
    }

    func bindByMove(to value: Emittable) {
        // Binding a property by move decrements its own ref-counter.
        managedValue?.release()

        // If the r-value isn't a managed value, a move binding is equivalent to a copy.
        guard let prop = value as? LocalProperty else {
            self.bindByCopy(to: value)
            return
        }

        // If the r-value is a managed value, we "steal" its pointer and leave it unbounded.
        builder.buildStore(prop.managedValue!.alloca, to: alloca)
        managedValue = prop.managedValue
        prop.managedValue = nil
    }

    /// The managed value bounded to the property.
    var managedValue: ManagedValue?

    // Reference to the IRBuilder associated with the module in which this property's defined.
    let builder: IRBuilder

    /// The alloca of the pointer to the managed value.
    let alloca: IRValue

    /// The Anzen semantic type of the property.
    let anzenType: SemanticType

    /// The LLVM IR type of the property.
    let llvmType: IRType

    /// The LLVM IR value representing the property.
    var val: IRValue {
        guard let value = managedValue
            else { return llvmType.null() }
        return value.val
    }

}

extension IRGenerator {

    public mutating func visit(_ node: PropDecl) throws {
        if let function = self.builder.insertBlock?.parent {
            try self.buildLocalProperty(node, in: function)
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

    private mutating func buildLocalProperty(_ node: PropDecl, in function: Function) throws {
        // Create the local property.
        let property = LocalProperty(in: function, anzenType: node.type!, builder: builder)
        self.locals.top?[node.name] = property

        // Generate the IR for optional the initial value.
        if let (op, value) = node.initialBinding {
            try self.buildBinding(to: property, op: op, valueOf: value)
        }
    }

}
