import Parsey

public enum Operator: CustomStringConvertible {
    case add, sub, mul, div
    case cpy, ref, mov

    public var description: String {
        switch self {
        case .add: return "+"
        case .sub: return "-"
        case .mul: return "*"
        case .div: return "/"
        case .cpy: return "="
        case .ref: return "&-"
        case .mov: return "<-"
        }
    }
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
            return "\(sign) \(self.qualifiers)"
        }
        return String(describing: self.qualifiers)
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

public class IntLiteral: Node {

    public init(value: Int, location: SourceRange? = nil) {
        self.value    = value
        self.location = location
    }

    public func accept(_ visitor: inout NodeVisitor) {
        visitor.visit(node: self)
    }

    public let value   : Int
    public var type    : Type? = nil
    public let location: SourceRange?

    public var description: String {
        return String(describing: self.value)
    }

}
