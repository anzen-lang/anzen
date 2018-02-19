import AnzenTypes
import Parsey

// MARK: Protocols

public protocol Node: class {

    var location: SourceRange? { get }

}

public protocol TypedNode: Node {

    var type: SemanticType? { get set }
}

public protocol ScopeNode: Node {

    var innerScope: Scope? { get set }
}

// MARK: Scopes

public class ModuleDecl: ScopeNode {

    public init(statements: [Node], location: SourceRange? = nil) {
        self.statements = statements
        self.location   = location
    }

    public var statements: [Node]

    // MARK: Annotations

    public let location  : SourceRange?
    public var innerScope: Scope? = nil

}

public class Block: ScopeNode {

    public init(statements: [Node], location: SourceRange? = nil) {
        self.statements = statements
        self.location   = location
    }

    public var statements: [Node]

    // MARK: Annotations

    public let location  : SourceRange?
    public var innerScope: Scope? = nil

}

// MARK: Declarations

public class FunDecl: TypedNode, ScopeNode {

    public init(
        name        : String,
        placeholders: [String] = [],
        parameters  : [ParamDecl],
        codomain    : Node? = nil,
        body        : Block,
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
    public let parameters  : [ParamDecl]
    public let codomain    : Node?
    public let body        : Block

    // MARK: Annotations

    public let location  : SourceRange?
    public var type      : SemanticType? = nil
    public var scope     : Scope? = nil
    public var innerScope: Scope? = nil

}

public class ParamDecl: TypedNode {

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
    public var type    : SemanticType? = nil
    public var scope   : Scope? = nil

}

public class PropDecl: TypedNode {

    public init(
        name          : String,
        reassignable  : Bool = false,
        typeAnnotation: Node? = nil,
        initialBinding: (op: Operator, value: Node)? = nil,
        location      : SourceRange? = nil)
    {
        self.name           = name
        self.reassignable   = reassignable
        self.typeAnnotation = typeAnnotation
        self.initialBinding = initialBinding
        self.location       = location
    }

    public let name          : String
    public let reassignable  : Bool
    public let typeAnnotation: Node?
    public let initialBinding: (op: Operator, value: Node)?

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : SemanticType? = nil
    public var scope   : Scope? = nil

}

public class StructDecl: TypedNode, ScopeNode {

    public init(
        name        : String,
        placeholders: [String] = [],
        body        : Block,
        location    : SourceRange? = nil)
    {
        self.name         = name
        self.placeholders = placeholders
        self.body         = body
        self.location     = location
    }

    public let name        : String
    public let placeholders: [String]
    public let body        : Block

    // MARK: Annotations

    public let location  : SourceRange?
    public var type      : SemanticType? = nil
    public var scope     : Scope? = nil
    public var innerScope: Scope? = nil

}

// MARK: Type signatures

public class QualSign: TypedNode {

    public init(
        qualifiers: [TypeQualifier], signature: Node?, location: SourceRange? = nil)
    {
        self.qualifiers = qualifiers
        self.signature  = signature
        self.location   = location
    }

    public let qualifiers: [TypeQualifier]
    public let signature : Node?

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : SemanticType? = nil

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
    public var type    : SemanticType? = nil

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
    public var type    : SemanticType? = nil

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

}

public class ReturnStmt: Node {

    public init(value: Node? = nil, location: SourceRange? = nil) {
        self.value     = value
        self.location = location
    }

    public let value: Node?

    // MARK: Annotations

    public let location: SourceRange?

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
    public var type    : SemanticType? = nil

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
    public var type    : SemanticType? = nil

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
    public var type    : SemanticType? = nil

}

public class CallExpr: TypedNode {

    public init(callee: Node, arguments: [CallArg], location: SourceRange? = nil) {
        self.callee    = callee
        self.arguments = arguments
        self.location  = location
    }

    public let callee   : Node
    public let arguments: [CallArg]

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : SemanticType? = nil

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
    public var type    : SemanticType? = nil

}

public class SubscriptExpr: TypedNode {

    public init(callee: Node, arguments: [CallArg], location: SourceRange? = nil) {
        self.callee    = callee
        self.arguments = arguments
        self.location  = location
    }

    public let callee   : Node
    public let arguments: [CallArg]

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : SemanticType? = nil

}

public class SelectExpr: TypedNode {

    public init(owner: Node? = nil, ownee: Ident, location: SourceRange? = nil) {
        self.owner    = owner
        self.ownee    = ownee
        self.location = location
    }

    public let owner: Node?
    public let ownee: Ident

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : SemanticType? = nil

}

public class Ident: TypedNode {

    public init(name: String, location: SourceRange? = nil) {
        self.name     = name
        self.location = location
    }

    public let name: String

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : SemanticType? = nil
    public var scope   : Scope? = nil

}

public class Literal<T>: TypedNode {

    public init(value: T, location: SourceRange? = nil) {
        self.value    = value
        self.location = location
    }

    public let value: T

    // MARK: Annotations

    public var type    : SemanticType? = nil
    public let location: SourceRange?

}
