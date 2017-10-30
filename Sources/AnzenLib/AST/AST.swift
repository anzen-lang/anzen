import Parsey

// MARK: Protocols

public protocol Node: class, CustomStringConvertible {

    var location: SourceRange? { get }

}

public protocol TypedNode: Node {

    var type: QualifiedType? { get set }
}

public protocol ScopeOpeningNode: Node {

    var symbols: Set<String> { get set }

}

public protocol ScopedNode: Node {

    var scope: Scope? { get set }

}

// MARK: Scopes

public class ModuleDecl: ScopeOpeningNode {

    public init(statements: [Node], location: SourceRange? = nil) {
        self.statements = statements
        self.location   = location
    }

    public var statements: [Node]

    // MARK: Annotations

    public let location: SourceRange?
    public var symbols : Set<String> = []

    // MARK: Pretty-printing

    public var description: String {
        return self.statements.map({ String(describing: $0) }).joined(separator: "\n")
    }

}

public class Block: ScopeOpeningNode {

    public init(statements: [Node], location: SourceRange? = nil) {
        self.statements = statements
        self.location   = location
    }

    public var statements: [Node]

    // MARK: Annotations

    public let location: SourceRange?
    public var symbols : Set<String> = []

    // MARK: Pretty-printing

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

public class FunDecl: TypedNode, ScopedNode {

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

    public let name        : String
    public let placeholders: [String]
    public let parameters  : [Node]
    public let codomain    : Node?
    public let body        : Node

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : QualifiedType? = nil
    public var scope   : Scope? = nil

    // MARK: Pretty-printing

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

public class ParamDecl: TypedNode, ScopedNode {

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

    public let label         : String?
    public let name          : String
    public let typeAnnotation: Node

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : QualifiedType? = nil
    public var scope   : Scope? = nil

    // MARK: Pretty-printing

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

public class PropDecl: TypedNode, ScopedNode {

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

    public let name          : String
    public let typeAnnotation: Node?
    public let initialBinding: (op: Operator, value: Node)?

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : QualifiedType? = nil
    public var scope   : Scope? = nil

    // MARK: Pretty-printing

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

public class StructDecl: TypedNode, ScopedNode {

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

    public let name        : String
    public let placeholders: [String]
    public let body        : Node

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : QualifiedType? = nil
    public var scope   : Scope? = nil

    // MARK: Pretty-printing

    public var description: String {
        var result = "struct \(self.name)"
        if !self.placeholders.isEmpty {
            result += "<" + self.placeholders.joined(separator: ", ") + ">"
        }
        return result + " \(self.body)"
    }

}

// MARK: Type signatures

public class QualSign: TypedNode {

    public init(
        qualifiers: TypeQualifier, signature: Node?, location: SourceRange? = nil)
    {
        self.qualifiers = qualifiers
        self.signature  = signature
        self.location   = location
    }

    public let qualifiers: TypeQualifier
    public let signature : Node?

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : QualifiedType? = nil

    // MARK: Pretty-printing

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

public class FunSign: TypedNode {

    public init(parameters: [Node], codomain: Node, location: SourceRange? = nil) {
        self.parameters = parameters
        self.codomain   = codomain
        self.location   = location
    }

    public let parameters: [Node]
    public let codomain  : Node

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : QualifiedType? = nil

    // MARK: Pretty-printing

    public var description: String {
        let parameters = self.parameters.map({ String(describing: $0) }).joined(separator: ", ")
        return "(\(parameters)) -> \(self.codomain)"
    }

}

public class ParamSign: TypedNode {

    public init(label: String?, typeAnnotation: Node, location: SourceRange? = nil) {
        self.label          = label
        self.typeAnnotation = typeAnnotation
        self.location       = location
    }

    public let label         : String?
    public let typeAnnotation: Node

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : QualifiedType? = nil

    // MARK: Pretty-printing

    public var description: String {
        let labelText = self.label ?? "_"
        return "\(labelText) \(self.typeAnnotation)"
    }

}

// MARK: Statements

public class BindingStmt: Node {

    public init(lvalue: Node, op: Operator, rvalue: Node, location: SourceRange? = nil) {
        self.lvalue   = lvalue
        self.op       = op
        self.rvalue   = rvalue
        self.location = location
    }

    public let lvalue: Node
    public let op    : Operator
    public let rvalue: Node

    // MARK: Annotations

    public let location: SourceRange?

    // MARK: Pretty-printing

    public var description: String {
        return "\(lvalue) \(op) \(rvalue)"
    }

}

public class ReturnStmt: Node {

    public init(value: Node? = nil, location: SourceRange? = nil) {
        self.value     = value
        self.location = location
    }

    public let value: Node?

    // MARK: Annotations

    public let location: SourceRange?

    // MARK: Pretty-printing

    public var description: String {
        return self.value != nil
            ? "return \(self.value!)"
            : "return"
    }

}

// MARK: Expressions

public class IfExpr: TypedNode {

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

    public let condition: Node
    public let thenBlock: Node
    public let elseBlock: Node?

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : QualifiedType? = nil

    // MARK: Pretty-printing

    public var description: String {
        var result = "if \(self.condition) \(self.thenBlock)"
        if let elseBlock = self.elseBlock {
            result += " else \(elseBlock)"
        }
        return result
    }

}

public class BinExpr: TypedNode {

    public init(left: Node, op: Operator, right: Node, location: SourceRange? = nil) {
        self.left     = left
        self.op       = op
        self.right    = right
        self.location = location
    }

    public let left : Node
    public let op   : Operator
    public let right: Node

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : QualifiedType? = nil

    // MARK: Pretty-printing

    public var description: String {
        return "(\(self.left) \(self.op) \(self.right))"
    }

}

public class UnExpr: TypedNode {

    public init(op: Operator, operand: Node, location: SourceRange? = nil) {
        self.op       = op
        self.operand  = operand
        self.location = location
    }

    public let op     : Operator
    public let operand: Node

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : QualifiedType? = nil

    // MARK: Pretty-printing

    public var description: String {
        return "(\(self.op) \(self.operand))"
    }

}

public class CallExpr: TypedNode {

    public init(callee: Node, arguments: [Node], location: SourceRange? = nil) {
        self.callee    = callee
        self.arguments = arguments
        self.location  = location
    }

    public let callee   : Node
    public let arguments: [Node]

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : QualifiedType? = nil

    // MARK: Pretty-printing

    public var description: String {
        let args = self.arguments.map({ String(describing: $0) }).joined(separator: ", ")
        return "\(self.callee)(\(args))"
    }

}

public class CallArg: TypedNode {

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

    public let label    : String?
    public let bindingOp: Operator?
    public let value    : Node

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : QualifiedType? = nil

    // MARK: Pretty-printing

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

public class SubscriptExpr: TypedNode {

    public init(callee: Node, arguments: [Node], location: SourceRange? = nil) {
        self.callee    = callee
        self.arguments = arguments
        self.location  = location
    }

    public let callee   : Node
    public let arguments: [Node]

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : QualifiedType? = nil

    // MARK: Pretty-printing

    public var description: String {
        let args = self.arguments.map({ String(describing: $0) }).joined(separator: ", ")
        return "\(self.callee)[\(args)]"
    }
}

public class SelectExpr: TypedNode {

    public init(owner: Node? = nil, ownee: Node, location: SourceRange? = nil) {
        self.owner    = owner
        self.ownee    = ownee
        self.location = location
    }

    public let owner: Node?
    public let ownee: Node

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : QualifiedType? = nil

    // MARK: Pretty-printing

    public var description: String {
        if let owner = self.owner {
            return "\(owner).\(self.ownee)"
        }
        return ".\(self.ownee)"
    }

}

public class Ident: TypedNode, ScopedNode {

    public init(name: String, location: SourceRange? = nil) {
        self.name     = name
        self.location = location
    }

    public let name: String

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : QualifiedType? = nil
    public var scope   : Scope? = nil

    // MARK: Pretty-printing

    public var description: String {
        return self.name
    }

}

public class Literal<T>: TypedNode {

    public init(value: T, location: SourceRange? = nil) {
        self.value    = value
        self.location = location
    }

    public let value: T

    // MARK: Annotations

    public var type    : QualifiedType? = nil
    public let location: SourceRange?

    // MARK: Pretty-printing

    public var description: String {
        return String(describing: self.value)
    }

}
