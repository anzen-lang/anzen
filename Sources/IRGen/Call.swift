import AnzenAST
import AnzenTypes
import LLVM
import Sema

/// The result of a function call.
///
/// As the way with which the result of a function (called with Anzen linkage) will be bound can't
/// be known from a `CallExpr` node alone, we use this special emittable value to represent return
/// values. It can be seen as a sort of constant pointer to a managed value.
///
/// - Attention: All binding operations should issue a release on the managed value of a call
///   result as soon as its value's been bound.
class CallResult: Referenceable {

    /// The Anzen semantic type of the call result.
    let anzenType: SemanticType

    /// The LLVM IR type of the call result.
    let llvmType: IRType

    /// The managed value bounded to the referenceable expression.
    var managedValue: ManagedValue?

    /// A pointer to the managed value.
    ///
    /// This should be the address of a pointer to a managed type (i.e. `{ i64, i8* T }*`) that
    /// either points to the address of the associated `managedValue`, or is `null` if the latter
    // isn't defined.
    let pointer: IRValue = IntType.int8*.null()

    /// The LLVM IR value representing the call result.
    var val: IRValue {
        return managedValue!.val
    }

    fileprivate init(anzenType: SemanticType, builder: IRBuilder) {
        self.anzenType = anzenType
        self.llvmType = builder.buildValueType(of: anzenType)
        self.managedValue = .allocate(anzenType: anzenType, builder: builder)
    }

}

extension IRGenerator {

    /// Emits the IR of a function call.
    public mutating func visit(_ node: CallExpr) throws {
        // FIXME: For now, we simply treat calls to `print` as special cases. But we won't have to
        // anymore when we'll implement C-link functions.
        if let callee = node.callee as? Ident, callee.name == "print" {
            // Create the format string.
            let format = builder.buildGlobalStringPtr("%ld\n", name: "str")

            // Generate the IR for the argument's value.
            try visit(node.arguments[0])
            let value = stack.pop()!

            // Generate the IR for the function call.
            // Note that we discard the result of calling `printf`.
            _ = builder.buildCall(printf, args: [format, value.val])
            return
        }

        // Allocate memory for the function's return value, if any.
        var argsVal: [IRValue] = []
        var returnVal: CallResult? = nil
        if !node.type!.equals(to: Builtins.instance.Nothing) {
            returnVal = CallResult(anzenType: node.type!, builder: builder)
            argsVal.append(returnVal!.managedValue!.alloca)
        }

        // Generate the IR for the arguments.
        let args = try node.arguments.map { callArg -> Emittable in
            try visit(callArg)
            return stack.pop()!
        }
        argsVal.append(contentsOf: args.map { ($0 as? LocalProperty)!.managedValue!.alloca })

        // FIXME: Create capture objects.
        argsVal.append(IntType.int8*.null())

        // Generate the IR for the function call.
        guard let calleeIdent = node.callee as? Ident else {
            fatalError("FIXME: implement non-ident callees")
        }
        let calleeName = Mangler.mangle(symbol: calleeIdent.symbol!)
        guard let calleeFn = llvmModule.function(named: calleeName) else {
            fatalError("undefined function: '\(calleeName)'")
        }
        _ = builder.buildCall(calleeFn, args: argsVal)
        if returnVal != nil {
            stack.push(returnVal!)
        }

        // Release all call arguments.
        for case let prop as LocalProperty in args {
            prop.managedValue?.release()
        }
    }

    /// Emits the IR of a call argument.
    public mutating func visit(_ node: CallArg) throws {
        guard let currentFn = builder.insertBlock?.parent else {
            fatalError("FIXME: allocate global result")
        }

        try visit(node.value)
        let val = stack.pop()!
        let arg = LocalProperty(in: currentFn, anzenType: node.type!, builder: builder)

        switch node.bindingOp {
        case .none, .cpy?: arg.bindByCopy(to: val)
        case .ref?       : arg.bindByReference(to: val)
        case .mov?       : arg.bindByMove(to: val)
        default:
            fatalError("unexpected binding operator")
        }

        // If the argument's value is the result of a call expression, it should be released.
        (val as? CallResult)?.managedValue?.release()

        stack.push(arg)
    }

}
