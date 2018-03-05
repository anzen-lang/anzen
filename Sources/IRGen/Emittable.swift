import AnzenTypes
import LLVM

/// Protocol for all LLVM IR emittable values.
protocol Emittable {

    /// The Anzen semantic type of the value.
    var anzenType: SemanticType { get }

    /// The LLVM IR type of the value.
    var llvmType: IRType { get }

    /// The LLVM IR value representing a reference (pointer) to the value.
    /// It may be `nil` in the case of non-referenceable values (e.g. literals).
    var ref: IRValue? { get }

    /// The LLVM IR value representing the value itself.
    var val: IRValue { get }

}

/// Represents a value on the stack (i.e. not wrapped within a managed object).
struct StackValue: Emittable {

    init(anzenType: SemanticType, llvmType: IRType, ref: IRValue? = nil, val: IRValue) {
        self.anzenType = anzenType
        self.llvmType = llvmType
        self.ref = ref
        self.val = val
    }

    let anzenType: SemanticType
    let llvmType: IRType
    let ref: IRValue?
    let val: IRValue

}
