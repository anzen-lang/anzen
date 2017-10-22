extension Module: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "Module:\n"

        if let desc = attrDesc(of: self.statements) {
            result += "- statements:\(desc)"
        }

        return result
    }

}

extension Block: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "Block:"

        if let desc = attrDesc(of: self.statements) {
            result += "- statements:\(desc)"
        }

        return result
    }

}

// MARK: Declarations

extension FunDecl: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "FunDecl:\n"

        result += "- name: \(self.name)\n"
        if let desc = attrDesc(of: self.placeholders) {
            result += "- placeholders:\(desc)"
        }
        if let desc = attrDesc(of: self.parameters) {
            result += "- parameters:\(desc)"
        }
        if let desc = attrDesc(of: self.codomain) {
            result += "- codomain:\(desc)"
        }
        if let desc = attrDesc(of: self.body) {
            result += "- body:\(desc)"
        }

        return result
    }

}

extension ParamDecl: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "ParamDecl:\n"

        if let desc = attrDesc(of: self.label) {
            result += "- label:\(desc)"
        }
        result += "- name: \(self.name)\n"
        if let desc = attrDesc(of: self.typeAnnotation) {
            result += "- typeAnnotation:\(desc)"
        }

        return result
    }

}

extension PropDecl: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "PropDecl:\n"

        result += "- name: \(self.name)\n"
        if let desc = attrDesc(of: self.typeAnnotation) {
            result += "- typeAnnotation:\(desc)"
        }
        if let (op, value) = self.initialBinding {
            result += "- initialBinding:\n"
            result += "  - operator: \(op)\n"
            result += "  - value:\n"
            for line in attrDesc(of: value)!.split(separator: "\n") {
                result += "  \(line)\n"
            }
        }

        return result
    }

}

extension StructDecl: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "StructDecl:\n"

        result += "- name: \(self.name)\n"
        if let desc = attrDesc(of: self.placeholders) {
            result += "- placeholders:\(desc)"
        }
        if let desc = attrDesc(of: self.body) {
            result += "- body:\(desc)"
        }

        return result
    }

}

// MARK: Type signatures

extension QualSign: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "QualSign:\n"

        let qualifiers = self.qualifiers != []
            ? String(describing: self.qualifiers)
            : "@?"
        result += "- qualifiers: \(qualifiers)\n"
        if let desc = attrDesc(of: self.signature) {
            result += "- signature:\(desc)"
        }

        return result
    }

}

extension FunSign: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "FunSign:\n"

        if let desc = attrDesc(of: self.parameters) {
            result += "- parameters:\(desc)"
        }
        if let desc = attrDesc(of: self.codomain) {
            result += "- codomain:\(desc)"
        }

        return result
    }

}

extension ParamSign: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "ParamSign:\n"

        if let desc = attrDesc(of: self.label) {
            result += "- label:\(desc)"
        }
        if let desc = attrDesc(of: self.typeAnnotation) {
            result += "- typeAnnotation:\(desc)"
        }

        return result
    }

}

// MARK: Statements

extension BindingStmt: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "BindingStmt:\n"

        if let desc = attrDesc(of: self.lvalue) {
            result += "- lvalue:\(desc)"
        }
        result += "- op: \(self.op)\n"
        if let desc = attrDesc(of: self.rvalue) {
            result += "- rvalue:\(desc)"
        }

        return result
    }

}

extension ReturnStmt: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "ReturnStmt:\n"

        if let desc = attrDesc(of: self.value) {
            result += "- value:\(desc)"
        }

        return result
    }

}

// MARK: Expressions

extension IfExpr: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "IfExpr:\n"

        if let desc = attrDesc(of: self.condition) {
            result += "- condition:\(desc)"
        }
        if let desc = attrDesc(of: self.thenBlock) {
            result += "- thenBlock:\(desc)"
        }
        if let desc = attrDesc(of: self.elseBlock) {
            result += "- elseBlock:\(desc)"
        }

        return result
    }

}

extension BinExpr: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "BinExpr:\n"

        if let desc = attrDesc(of: self.left) {
            result += "- left:\(desc)"
        }
        result += "- op: \(self.op)\n"
        if let desc = attrDesc(of: self.right) {
            result += "- right:\(desc)"
        }

        return result
    }

}

extension UnExpr: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "UnExpr:\n"

        result += "- op: \(self.op)\n"
        if let desc = attrDesc(of: self.operand) {
            result += "- right:\(desc)"
        }

        return result
    }

}

extension CallExpr: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "CallExpr:\n"

        if let desc = attrDesc(of: self.callee) {
            result += "- callee:\(desc)"
        }
        if let desc = attrDesc(of: self.arguments) {
            result += "- arguments:\(desc)"
        }

        return result
    }

}

extension CallArg: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "CallArg:\n"

        if let desc = attrDesc(of: self.label) {
            result += "- label:\(desc)"
        }
        if let desc = attrDesc(of: self.bindingOp) {
            result += "- bindingOp:\(desc)"
        }
        if let desc = attrDesc(of: self.value) {
            result += "- value:\(desc)"
        }

        return result
    }

}

extension SubscriptExpr: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "SubscriptExpr:\n"

        if let desc = attrDesc(of: self.callee) {
            result += "- callee:\(desc)"
        }
        if let desc = attrDesc(of: self.arguments) {
            result += "- arguments:\(desc)"
        }

        return result
    }

}

extension SelectExpr: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "SelectExpr:\n"

        if let desc = attrDesc(of: self.owner) {
            result += "- owner:\(desc)"
        }
        if let desc = attrDesc(of: self.ownee) {
            result += "- ownee:\(desc)"
        }

        return result
    }

}

extension Ident: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "Ident:\n"

        result += "- name: \(self.name)\n"

        return result
    }

}

extension Literal: CustomDebugStringConvertible {

    public var debugDescription: String {
        var result = "Literal:\n"

        result += "- value: \(self.value)\n"

        return result
    }

}

// MARK: Helpers

fileprivate func attrDesc(of attribute: [Node]) -> String? {
    guard !attribute.isEmpty else {
        return nil
    }

    var result = "\n"
    for child in attribute {
        let childDescription = String(reflecting: child).split(separator: "\n")
        result += "  - \(childDescription[0])\n"
        for line in childDescription.dropFirst() {
            result += "    \(line)\n"
        }
    }
    return result
}

fileprivate func attrDesc(of attribute: Node?) -> String? {
    guard attribute != nil else {
        return nil
    }

    let childDescription = String(reflecting: attribute!).split(separator: "\n")
    if childDescription.count == 1 {
        return " \(childDescription[0])\n"
    } else {
        var result = "\n"
        result += "  - \(childDescription[0])\n"
        for line in childDescription.dropFirst() {
            result += "    \(line)\n"
        }
        return result
    }
}

fileprivate func attrDesc<T>(of attribute: T?) -> String? {
    guard attribute != nil else {
        return nil
    }
    return " \(attribute!)\n"
}
