import AnzenTypes
import LLVM

/// Protocol for all LLVM IR emittable values.
protocol Emittable {

    /// The Anzen semantic type of the value.
    var anzenType: SemanticType { get }

    /// The LLVM IR type of the value.
    var llvmType: IRType { get }

    /// The LLVM IR value representing the value.
    var val: IRValue { get }

}

/// Represents an unmanaged value.
struct UnmanagedValue: Emittable {

    init(anzenType: SemanticType, llvmType: IRType, val: IRValue) {
        self.anzenType = anzenType
        self.llvmType = llvmType
        self.val = val
    }

    /// The Anzen semantic type of the value.
    let anzenType: SemanticType

    /// The LLVM IR type of the value.
    let llvmType: IRType

    /// The LLVM IR value representing the value.
    let val: IRValue

}

/// Represents a managed (i.e. garbage collected) value.
struct ManagedValue: Emittable {

    init(anzenType: SemanticType, llvmType: IRType, builder: IRBuilder, alloca: IRValue) {
        self.anzenType = anzenType
        self.llvmType = llvmType
        self.builder = builder
        self.alloca = alloca
    }

    /// Emit a retain.
    mutating func retain() {
        referenceCount = builder.buildAdd(referenceCount, NativeInt.constant(1))
    }

    /// Emit a release.
    mutating func release() {
        referenceCount = builder.buildSub(referenceCount, NativeInt.constant(1))
    }

    /// Reference to the IRBuilder associated with the module in which this value's defined.
    let builder: IRBuilder

    /// The alloca of the managed value.
    let alloca: IRValue

    /// The Anzen semantic type of the value.
    let anzenType: SemanticType

    /// The LLVM IR type of the value.
    let llvmType: IRType

    /// The LLVM IR value representing the value.
    var val: IRValue {
        get {
            return builder.buildLoad(builder.buildStructGEP(alloca, index: 2))
        }
        set {
            builder.buildStore(newValue, to: builder.buildStructGEP(alloca, index: 2))
        }
    }

    /// The LLVM IR value representing the reference count.
    var referenceCount: IRValue {
        get {
            return builder.buildLoad(builder.buildStructGEP(alloca, index: 0))
        }
        set {
            builder.buildStore(newValue, to: builder.buildStructGEP(alloca, index: 0))
        }
    }

    /// Allocate a new managed value.
    static func allocate(anzenType: SemanticType, builder: IRBuilder) -> ManagedValue {
        let llvmType = builder.buildValueType(of: anzenType)
        let size     = builder.module.dataLayout.abiSize(of: llvmType)
        let memory   = builder.buildCallToMalloc(size)
        let alloca   = builder.buildBitCast(memory, type: llvmType*)
        var value    = ManagedValue(
            anzenType: anzenType, llvmType: llvmType, builder: builder, alloca: alloca)

        value.referenceCount = NativeInt.constant(1)
        return value
    }

}
