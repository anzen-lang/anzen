import AnzenTypes
import LLVM

/// Protocol for all LLVM IR emittable expressions.
///
/// An emittable expression represents a r-value that may be consumed by a binding. All AST nodes
/// representing an expression must be reducible to an emmitable type.
protocol Emittable {

    /// The Anzen semantic type of the expression.
    var anzenType: SemanticType { get }

    /// The LLVM IR type of the expression.
    var llvmType: IRType { get }

    /// The LLVM IR value representing the expression.
    var val: IRValue { get }

}

/// Protocol for referenceable expressions.
///
/// A referenceable emittable expression is a pointer to a managed value.
protocol Referenceable: Emittable {

    /// The managed value bounded to the referenceable expression.
    var managedValue: ManagedValue? { get set }

    /// A pointer to the managed value.
    ///
    /// This should be the address of a pointer to a managed type (i.e. `{ i64, i8* T }*`) that
    /// either points to the address of the associated `managedValue`, or is `null` if the latter
    // isn't defined.
    var pointer: IRValue { get }

}

/// Represents an unmanaged value (e.g. a literal).
struct UnmanagedValue: Emittable {

    /// The Anzen semantic type of the value.
    let anzenType: SemanticType

    /// The LLVM IR type of the value.
    let llvmType: IRType

    /// The LLVM IR value representing the value.
    let val: IRValue

}

/// Represents a managed (i.e. garbage collected) value.
///
/// A managed value is a structure whose two first fields are a reference counter and a pointer to
/// the runtime metadata associated with the value.
class ManagedValue: Emittable {

    init(anzenType: SemanticType, llvmType: IRType? = nil, builder: IRBuilder, alloca: IRValue) {
        self.anzenType = anzenType
        self.llvmType = llvmType ?? builder.buildValueType(of: anzenType)
        self.builder = builder
        self.alloca = alloca
    }

    /// Emits a retain.
    func retain() {
        referenceCount = builder.buildAdd(referenceCount, NativeInt.constant(1))
    }

    /// Emits a release.
    func release() {
        referenceCount = builder.buildSub(referenceCount, NativeInt.constant(1))
    }

    /// The Anzen semantic type of the wrapped value.
    let anzenType: SemanticType

    /// The LLVM IR type of the wrapped value.
    let llvmType: IRType

    /// Reference to the IRBuilder associated with the module in which the value's defined.
    let builder: IRBuilder

    /// The alloca of the wrapper.
    ///
    /// This should be the address of a managed type, i.e. an instance of a type of the form
    /// `{ i64, i8*, T }`, where T is the type of the wrapped value.
    let alloca: IRValue

    /// The LLVM IR value representing the wrapped value.
    ///
    /// Use this property to emit load/store instructions from/to the actual managed value.
    var val: IRValue {
        get {
            return builder.buildLoad(builder.buildStructGEP(alloca, index: 2))
        }
        set {
            builder.buildStore(newValue, to: builder.buildStructGEP(alloca, index: 2))
        }
    }

    /// The LLVM IR value representing the reference count.
    private var referenceCount: IRValue {
        get {
            return builder.buildLoad(builder.buildStructGEP(alloca, index: 0))
        }
        set {
            builder.buildStore(newValue, to: builder.buildStructGEP(alloca, index: 0))
        }
    }

    /// Allocates a new managed value on the head.
    static func allocate(anzenType: SemanticType, builder: IRBuilder) -> ManagedValue {
        // Allocate memory on for the wrapper on the heap.
        let llvmType = builder.buildValueType(of: anzenType)
        let size = builder.module.dataLayout.abiSize(of: llvmType)
        let alloca = builder.buildBitCast(builder.buildCallToMalloc(size), type: llvmType*)

        /// Create the managed value.
        let value = ManagedValue(
            anzenType: anzenType,
            llvmType: llvmType,
            builder: builder,
            alloca: alloca)

        value.referenceCount = NativeInt.constant(1)
        return value
    }

}
