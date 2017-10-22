import Parsey

public enum Operator: CustomStringConvertible {
    case not
    case mul , div , mod
    case add , sub
    case lt  , le  , gt  , ge
    case eq  , ne
    case and
    case or
    case cpy , ref , mov

    public var description: String {
        return Operator.repr[self]!
    }

    public static var repr: [Operator: String] = [
        .not : "not",
        .mul : "*"  , .div : "/"  , .mod : "%"  ,
        .add : "+"  , .sub : "-"  ,
        .lt  : "<"  , .le  : "<=" , .gt  : ">"  , .ge:  ">=" ,
        .eq  : "==" , .ne  : "!=" ,
        .and : "and",
        .or  : "or" ,
        .cpy : "="  , .ref : "&-" , .mov : "<-" ,
    ]
}

public protocol NodeVisitor {

    mutating func visit(node: Node)

}

public protocol Node: CustomStringConvertible {

    func accept(_ visitor: inout NodeVisitor)

    var location: SourceRange? { get }
    var type    : Type?        { get set }

}

public class Module: Node {

    public init(statements: [Node], location: SourceRange? = nil) {
        self.statements = statements
        self.location   = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public var statements: [Node]
    public var type      : Type? = nil
    public let location  : SourceRange?

    public var description: String {
        return self.statements.map({ String(describing: $0) }).joined(separator: "\n")
    }

}

public class Block: Node {

    public init(statements: [Node], location: SourceRange? = nil) {
        self.statements = statements
        self.location   = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public var statements: [Node]
    public var type      : Type? = nil
    public let location  : SourceRange?

    public var description: String {
        var result = "{\n"
        for stmt in self.statements {
            result += String(describing: stmt)
                .split(separator: "\n")
                .map({ "  " + $0 })
                .joined(separator: "\n")
            result += "\n"
        }
        return result + "}"
    }

}

public class FunDecl: Node {

    public init(
        name        : String,
        placeholders: [String] = [],
        parameters  : [Node],
        codomain    : Node? = nil,
        body        : Node,
        location    : SourceRange? = nil)
    {
        self.name         = name
        self.placeholders = placeholders
        self.parameters   = parameters
        self.codomain     = codomain
        self.body         = body
        self.location     = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let name         : String
    public let placeholders : [String]
    public let parameters   : [Node]
    public let codomain     : Node?
    public let body         : Node
    public var type         : Type? = nil
    public let location     : SourceRange?

    public var description: String {
        var result = "function \(self.name)"
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

public class ParamDecl: Node {

    public init(
        label         : String?,
        name          : String,
        typeAnnotation: Node,
        location      : SourceRange? = nil)
    {
        self.label          = label
        self.name           = name
        self.typeAnnotation = typeAnnotation
        self.location       = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let label         : String?
    public let name          : String
    public let typeAnnotation: Node
    public var type          : Type? = nil
    public let location      : SourceRange?

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

public class PropDecl: Node {

    public init(
        name          : String,
        typeAnnotation: Node? = nil,
        initialBinding: (op: Operator, value: Node)? = nil,
        location      : SourceRange? = nil)
    {
        self.name           = name
        self.typeAnnotation = typeAnnotation
        self.initialBinding = initialBinding
        self.location       = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let name          : String
    public let typeAnnotation: Node?
    public let initialBinding: (op: Operator, value: Node)?
    public var type          : Type? = nil
    public let location      : SourceRange?

    public var description: String {
        var result = "let \(self.name)"
        if let annotation = self.typeAnnotation {
            result += ": \(annotation)"
        }
        if let (op, val) = self.initialBinding {
            result += " \(op) \(val)"
        }
        return result
    }

}

public class StructDecl: Node {

    public init(
        name        : String,
        placeholders: [String] = [],
        body        : Node,
        location    : SourceRange? = nil)
    {
        self.name         = name
        self.placeholders = placeholders
        self.body         = body
        self.location     = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let name        : String
    public let placeholders: [String]
    public let body        : Node
    public var type        : Type? = nil
    public let location    : SourceRange?

    public var description: String {
        var result = "struct \(self.name)"
        if !self.placeholders.isEmpty {
            result += "<" + self.placeholders.joined(separator: ", ") + ">"
        }
        return result + " \(self.body)"
    }
}

public class TypeAnnot: Node {

    public init(
        qualifiers: TypeQualifier, signature: Node?, location: SourceRange? = nil)
    {
        self.qualifiers = qualifiers
        self.signature  = signature
        self.location   = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let qualifiers: TypeQualifier
    public let signature : Node?
    public var type      : Type? = nil
    public let location  : SourceRange?

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

public class FunSign: Node {

    public init(parameters: [Node], codomain: Node, location: SourceRange? = nil) {
        self.parameters = parameters
        self.codomain   = codomain
        self.location   = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let parameters : [Node]
    public let codomain   : Node
    public var type       : Type? = nil
    public let location   : SourceRange?

    public var description: String {
        let parameters = self.parameters.map({ String(describing: $0) }).joined(separator: ", ")
        return "(\(parameters)) -> \(self.codomain)"
    }

}

public class ParamSign: Node {

    public init(label: String?, typeAnnotation: Node, location: SourceRange? = nil) {
        self.label          = label
        self.typeAnnotation = typeAnnotation
        self.location       = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let label         : String?
    public let typeAnnotation: Node
    public var type          : Type? = nil
    public let location      : SourceRange?

    public var description: String {
        let labelText = self.label ?? "_"
        return "\(labelText) \(self.typeAnnotation)"
    }

}

public class BindingStmt: Node {

    public init(lvalue: Node, op: Operator, rvalue: Node, location: SourceRange? = nil) {
        self.lvalue   = lvalue
        self.op       = op
        self.rvalue   = rvalue
        self.location = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let lvalue  : Node
    public let op      : Operator
    public let rvalue  : Node
    public var type    : Type? = nil
    public let location: SourceRange?

    public var description: String {
        return "\(lvalue) \(op) \(rvalue)"
    }

}

public class ReturnStmt: Node {

    public init(value: Node? = nil, location: SourceRange? = nil) {
        self.value     = value
        self.location = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let value   : Node?
    public var type    : Type? = nil
    public let location: SourceRange?

    public var description: String {
        return self.value != nil
            ? "return \(self.value!)"
            : "return"
    }

}

public class IfExpr: Node {

    public init(
        condition: Node,
        thenBlock: Node,
        elseBlock: Node? = nil,
        location : SourceRange? = nil)
    {
        self.condition = condition
        self.thenBlock = thenBlock
        self.elseBlock = elseBlock
        self.location  = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let condition: Node
    public let thenBlock: Node
    public let elseBlock: Node?
    public var type     : Type? = nil
    public let location : SourceRange?

    public var description: String {
        var result = "if \(self.condition) \(self.thenBlock)"
        if let elseBlock = self.elseBlock {
            result += " else \(elseBlock)"
        }
        return result
    }

}

public class BinExpr: Node {

    public init(left: Node, op: Operator, right: Node, location: SourceRange? = nil) {
        self.left     = left
        self.op       = op
        self.right    = right
        self.location = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let left     : Node
    public let op       : Operator
    public let right    : Node
    public var type     : Type? = nil
    public let location : SourceRange?

    public var description: String {
        return "(\(self.left) \(self.op) \(self.right))"
    }

}

public class UnExpr: Node {

    public init(op: Operator, operand: Node, location: SourceRange? = nil) {
        self.op       = op
        self.operand  = operand
        self.location = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let op       : Operator
    public let operand  : Node
    public var type     : Type? = nil
    public let location : SourceRange?

    public var description: String {
        return "(\(self.op) \(self.operand))"
    }

}

public class CallExpr: Node {

    public init(callee: Node, arguments: [Node], location: SourceRange? = nil) {
        self.callee    = callee
        self.arguments = arguments
        self.location  = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let callee   : Node
    public let arguments: [Node]
    public var type     : Type? = nil
    public let location : SourceRange?

    public var description: String {
        let args = self.arguments.map({ String(describing: $0) }).joined(separator: ", ")
        return "\(self.callee)(\(args))"
    }

}

public class CallArg: Node {

    public init(
        label    : String? = nil,
        bindingOp: Operator? = nil,
        value    : Node,
        location : SourceRange? = nil)
    {
        self.label     = label
        self.bindingOp = bindingOp
        self.value     = value
        self.location  = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let label    : String?
    public let bindingOp: Operator?
    public let value    : Node
    public var type     : Type? = nil
    public let location : SourceRange?

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

public class SubscriptExpr: Node {

    public init(callee: Node, arguments: [Node], location: SourceRange? = nil) {
        self.callee    = callee
        self.arguments = arguments
        self.location  = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let callee   : Node
    public let arguments: [Node]
    public var type     : Type? = nil
    public let location : SourceRange?

    public var description: String {
        let args = self.arguments.map({ String(describing: $0) }).joined(separator: ", ")
        return "\(self.callee)[\(args)]"
    }
}

public class SelectExpr: Node {

    public init(owner: Node? = nil, member: Node, location: SourceRange? = nil) {
        self.owner    = owner
        self.member   = member
        self.location = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let owner   : Node?
    public let member  : Node
    public var type    : Type? = nil
    public let location: SourceRange?

    public var description: String {
        if let owner = self.owner {
            return "\(owner).\(self.member)"
        }
        return ".\(self.member)"
    }

}

public class Ident: Node {

    public init(name: String, location: SourceRange? = nil) {
        self.name     = name
        self.location = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let name    : String
    public var type    : Type? = nil
    public let location: SourceRange?

    public var description: String {
        return self.name
    }

}

public class Literal<T>: Node {

    public init(value: T, location: SourceRange? = nil) {
        self.value    = value
        self.location = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let value   : T
    public var type    : Type? = nil
    public let location: SourceRange?

    public var description: String {
        return String(describing: self.value)
    }

}
