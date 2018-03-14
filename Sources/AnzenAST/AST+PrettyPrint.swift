// MARK: Scopes

extension ModuleDecl: CustomStringConvertible {

    public var description: String {
        return self.statements.map({ String(describing: $0) }).joined(separator: "\n")
    }

}

extension Block: CustomStringConvertible {

    public var description: String {
        var result = "{\n"
        for stmt in self.statements {
            result += String(describing: stmt)
                .split(separator: "\n")
                .map({ "  " + $0 })
                .joined(separator: "\n") + "\n"
        }
        return result + "}"
    }

}

// MARK: Declarations

extension FunDecl: CustomStringConvertible {

    public var description: String {
        var result = self.attributes.isEmpty
            ? ""
            : self.attributes.map({ String(describing: $0) }).joined(separator: " ") + " "
        result += "fun \(self.name)"
        if !self.placeholders.isEmpty {
            result += "<" + self.placeholders.joined(separator: ", ") + ">"
        }
        result += "("
        result += self.parameters.map({ String(describing: $0) }).joined(separator: ", ")
        result += ")"
        if let annotation = self.codomain {
            result += " -> \(annotation)"
        }
        return result + " \(self.body)"
    }

}

extension ParamDecl: CustomStringConvertible {

    public var description: String {
        var interface = self.name
        if let label = self.label {
            if label != self.name {
                interface = "\(label) \(interface)"
            }
        } else {
            interface = "_ \(interface)"
        }
        return "\(interface): \(self.typeAnnotation)"
    }

}

extension PropDecl: CustomStringConvertible {

    public var description: String {
        var result = self.reassignable
            ? "var "
            : "let "
        result += self.name
        if let annotation = self.typeAnnotation {
            result += ": \(annotation)"
        }
        if let (op, val) = self.initialBinding {
            result += " \(op) \(val)"
        }
        return result
    }

}

extension StructDecl: CustomStringConvertible {

    public var description: String {
        var result = "struct \(self.name)"
        if !self.placeholders.isEmpty {
            result += "<" + self.placeholders.joined(separator: ", ") + ">"
        }
        return result + " \(self.body)"
    }

}

extension InterfaceDecl: CustomStringConvertible {

    public var description: String {
        var result = "interface \(self.name)"
        if !self.placeholders.isEmpty {
            result += "<" + self.placeholders.joined(separator: ", ") + ">"
        }
        return result + " \(self.body)"
    }

}

extension PropReq: CustomStringConvertible {

    public var description: String {
        let result = self.reassignable
            ? "var "
            : "let "
        return result + "\(self.name): \(self.typeAnnotation)"
    }

}

extension FunReq: CustomStringConvertible {

    public var description: String {
        var result = self.attributes.isEmpty
            ? ""
            : self.attributes.map({ String(describing: $0) }).joined(separator: " ") + " "
        result += "fun \(self.name)"
        if !self.placeholders.isEmpty {
            result += "<" + self.placeholders.joined(separator: ", ") + ">"
        }
        result += "("
        result += self.parameters.map({ String(describing: $0) }).joined(separator: ", ")
        result += ")"
        if let annotation = self.codomain {
            result += " -> \(annotation)"
        }
        return result
    }

}

// MARK: Type signatures

extension QualSign: CustomStringConvertible {

    public var description: String {
        if let sign = self.signature {
            let qual = String(describing: self.qualifiers)
            return qual != ""
                ? "\(qual) \(sign)"
                : String(describing: sign)
        }
        return String(describing: self.qualifiers)
    }

}

extension FunSign: CustomStringConvertible {

    public var description: String {
        let parameters = self.parameters.map({ String(describing: $0) }).joined(separator: ", ")
        return "(\(parameters)) -> \(self.codomain)"
    }

}

extension ParamSign: CustomStringConvertible {

    public var description: String {
        let labelText = self.label ?? "_"
        return "\(labelText) \(self.typeAnnotation)"
    }

}

// MARK: Statements

extension BindingStmt: CustomStringConvertible {

    public var description: String {
        return "\(lvalue) \(op) \(rvalue)"
    }

}

extension ReturnStmt: CustomStringConvertible {

    public var description: String {
        let op: String
        if let bindingOp = self.bindingOp {
            op = bindingOp.description + " "
        } else {
            op = ""
        }
        return self.value != nil
            ? "return \(op)\(self.value!)"
            : "return"
    }

}

// MARK: Expressions

extension IfExpr: CustomStringConvertible {

    public var description: String {
        var result = "if \(self.condition) \(self.thenBlock)"
        if let elseBlock = self.elseBlock {
            result += " else \(elseBlock)"
        }
        return result
    }

}

extension BinExpr: CustomStringConvertible {

    public var description: String {
        return "(\(self.left) \(self.op) \(self.right))"
    }

}

extension UnExpr: CustomStringConvertible {

    public var description: String {
        return "(\(self.op) \(self.operand))"
    }

}

extension CallExpr: CustomStringConvertible {

    public var description: String {
        let args = self.arguments.map({ String(describing: $0) }).joined(separator: ", ")
        return "\(self.callee)(\(args))"
    }

}

extension CallArg: CustomStringConvertible {

    public var description: String {
        if let label = self.label, let op = self.bindingOp {
            return "\(label) \(op) \(self.value)"
        }
        if let op = self.bindingOp {
            return "\(op) \(self.value)"
        }
        return String(describing: self.value)
    }

}

extension SubscriptExpr: CustomStringConvertible {

    public var description: String {
        let args = self.arguments.map({ String(describing: $0) }).joined(separator: ", ")
        return "\(self.callee)[\(args)]"
    }

}

extension SelectExpr: CustomStringConvertible {

    public var description: String {
        if let owner = self.owner {
            return "\(owner).\(self.ownee)"
        }
        return ".\(self.ownee)"
    }

}

extension Ident: CustomStringConvertible {

    public var description: String {
        var result = self.name
        if !self.specializations.isEmpty {
            let specializations = self.specializations
                .map   ({ "\($0.key) = \($0.value)" })
                .joined(separator: ", ")
            result += "<" + specializations + ">"
        }
        return result
    }

}

extension Literal: CustomStringConvertible {

    public var description: String {
        return String(describing: self.value)
    }

}

// MARK: Operators

extension PrefixOperator: CustomStringConvertible {

    public var description: String { return rawValue }

}

extension InfixOperator: CustomStringConvertible {

    public var description: String { return rawValue }

}

extension BindingOperator: CustomStringConvertible {

    public var description: String { return rawValue }

}
