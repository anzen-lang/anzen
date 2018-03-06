import LLVM

struct Runtime {

    unowned let module: Module
    unowned let builder: IRBuilder

    /// Returns the type of the runtime `azn_gc_object`.
    var gc_object: IRType {
        if let ty = self.module.type(named: "struct.azn_gc_object") {
            return ty
        }

        let ty = self.builder.createStruct(name: "struct.azn_gc_object")
        ty.setBody([ IntType.int8*, Runtime.destructorType*, NativeInt* ])
        return ty
    }

    /// Returns the a reference to the runtime `azn_gc_object_init`.
    var gc_object_init: Function {
        if let fn = self.module.function(named: "azn_gc_object_init") {
            return fn
        }
        return self.declareFunction(
            name: "azn_gc_object_init",
            argTypes: [ self.gc_object*, NativeInt, Runtime.destructorType* ],
            returnType: VoidType())
    }

    /// Returns the a reference to the runtime `azn_gc_object_retain`.
    var gc_object_retain: Function {
        if let fn = self.module.function(named: "azn_gc_object_retain") {
            return fn
        }
        return self.declareFunction(
            name: "azn_gc_object_retain", argTypes: [ self.gc_object* ], returnType: VoidType())
    }

    /// Returns the a reference to the runtime `azn_gc_object_release`.
    var gc_object_release: Function {
        if let fn = self.module.function(named: "azn_gc_object_release") {
            return fn
        }
        return self.declareFunction(
            name: "azn_gc_object_retain", argTypes: [ self.gc_object* ], returnType: VoidType())
    }

    /// The type of a destructor.
    static let destructorType = FunctionType(argTypes: [IntType.int8*], returnType: VoidType())

    private func declareFunction(
        name: String, argTypes: [IRType], returnType: IRType) -> Function
    {
        var fn = self.builder.addFunction(
            name, type: LLVM.FunctionType(argTypes: argTypes, returnType: returnType))
        fn.linkage = .external
        fn.callingConvention = .c
        return fn
    }

}
