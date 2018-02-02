import LLVM

extension IRGenerator {

    mutating func createStore(
        _ rvalue: ValueBinding, op: Operator, to dest: ValueBinding) throws
    {
        switch op {
        case .cpy: try createCpyStore(rvalue, to: dest)
        case .ref: try createRefStore(rvalue, to: dest)

        default:
            assertionFailure("unexpected binding operator '\(op)'")
        }
    }

    func createCpyStore(_ rvalue: ValueBinding, to dest: ValueBinding) throws {
        // Dereference the lvalue and/or rvalue as needed.
        let ptr = dest.qualifiers.contains(.ref)
            ? self.builder.buildLoad(dest.ref)
            : dest.ref
        let val = rvalue.qualifiers.contains(.ref)
            ? self.builder.buildLoad(rvalue.read())
            : rvalue.read()

        self.builder.buildStore(val, to: ptr)
    }

    func createRefStore(_ rvalue: ValueBinding, to dest: ValueBinding) throws {
        assert(dest.qualifiers.contains(.ref))

        // Dereference the rvalue as needed.
        let val = rvalue.qualifiers.contains(.ref)
            ? rvalue.read()
            : rvalue.ref

        self.builder.buildStore(val, to: dest.ref)
    }

}
