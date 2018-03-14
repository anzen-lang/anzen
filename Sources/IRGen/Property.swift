import AnzenAST
import AnzenTypes
import LLVM

/// Protocol for local and global properties.
///
/// A property represents a read/write store that may be bound to a value.
protocol Property: Referenceable {

    /// Emits the instructions to bind this property to the given emittable, with the semantics
    /// associated with the given binding operator.
    func bind(to expr: Emittable, by op: BindingOperator)

    /// Emits the instructions to bind this property to a copy of the given emittable.
    func bindByCopy(to expr: Emittable)

    /// Emits the instructions to bind the property to a reference on the given emittable.
    func bindByReference(to expr: Emittable)

    /// Emits the instructions to bind the property to the value of the given emittable, and
    /// transfers its ownership.
    func bindByMove(to expr: Emittable)

}

extension Property {

    /// Emits the instructions to bind this property to the given emittable, with the semantics
    /// associated with the given binding operator.
    func bind(to expr: Emittable, by op: BindingOperator) {
        switch op {
        case .copy: bindByCopy(to: expr)
        case .ref : bindByReference(to: expr)
        case .move: bindByMove(to: expr)
        }
    }

}

/// A local property.
class LocalProperty: Property {

    init(in function: Function, anzenType: SemanticType, builder: IRBuilder) {
        self.anzenType = anzenType
        self.llvmType = builder.buildValueType(of: anzenType)
        self.builder = builder
        self.pointer = builder.buildEntryAlloca(in: function, type: self.llvmType*)
    }

    /// Emits the instructions to bind this property to a copy of the given emittable.
    func bindByCopy(to expr: Emittable) {
        // Allocate the property's memory if it is unbound.
        if managedValue == nil {
            managedValue = ManagedValue.allocate(anzenType: anzenType, builder: builder)
        }

        // Copy the value of the emittable.
        // FIXME: use deepcopy
        managedValue!.val = expr.val
    }

    /// Emits the instructions to bind the property to a reference on the given emittable.
    func bindByReference(to expr: Emittable) {
        guard let ref = expr as? Referenceable else {
            fatalError("cannot emit reference binding to non-referenceable expression")
        }

        // Decrements the reference count of the property, since it's about to be rebound.
        managedValue?.release()

        // Rebind the property.
        // Note that the retain will be performed on the newly bound managed value.
        managedValue = ref.managedValue
        managedValue!.retain()
    }

    /// Emits the instructions to bind the property to the value of the given emittable, and
    /// transfers its ownership.
    func bindByMove(to expr: Emittable) {
        // Decrements the reference count of the property, since it's about to be rebound.
        managedValue?.release()

        // If the r-value is referenceable, this property should "steal" the r-value's reference,
        // and leave it unbound. Otherwise the binding is equivalent to a copy.
        if var ref = expr as? Referenceable {
            managedValue = ref.managedValue
            ref.managedValue = nil
        } else {
            bindByCopy(to: expr)
        }
    }

    /// The Anzen semantic type of the property.
    let anzenType: SemanticType

    /// The LLVM IR type of the property.
    let llvmType: IRType

    /// The managed value bounded to the property.
    var managedValue: ManagedValue? {
        didSet {
            if managedValue != nil { builder.buildStore(managedValue!.alloca, to: pointer) }
        }
    }

    // Reference to the IRBuilder associated with the module in which this property's defined.
    let builder: IRBuilder

    /// A pointer to the managed value.
    ///
    /// This should be the address of a pointer to a managed type (i.e. `{ i64, i8* T }*`) that
    /// points to the address of the associated `managedValue` if it's set.
    let pointer: IRValue

    /// The LLVM IR value representing the property.
    var val: IRValue {
        guard let value = managedValue
            else { return llvmType.null() }
        return value.val
    }

}
