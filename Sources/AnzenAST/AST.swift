import AnzenTypes
import Parsey

// MARK: Protocols

/// Common interface for all AST nodes.
///
/// An Abstract Syntax Tree (AST) is a tree representation of a source code. Each node represents
/// a particular construction (e.g. a variable declaration), with each child representing a sub-
/// construction (e.g. the name of the variable being declared). The term "abstract" denotes the
/// fact that concrete syntactic details such as line returns, extra parenthesis, etc. are
/// *abstracted* away.
public protocol Node: class, CustomStringConvertible {

    /// Stores the location in the source file of the concrete syntax this node represents.
    var location: SourceRange? { get }

}

/// Common interface for typed nodes.
///
/// Some nodes of the AST are annotated with a type, either defined explicityl from the source, or
/// automatically inferred during the semantic analysis phase (SEMA).
///
/// Note that Anzen distinguishes between semantic types, which denote the nature of a value (e.g.
/// `Int`) and contextual types, which also describe the capabilities of a value at a given time
/// (e.g. whether the value is read-only).
public protocol TypedNode: Node {

    /// The semantic type of the node.
    var type: SemanticType? { get set }

}

/// Common interface for nodes that introduce a new scope.
///
/// Some nodes of the AST introduce a new lexical (a.k.a. static) scope, which is a region defining
/// the lifetime of variables.
public protocol ScopeNode: Node {

    /// A reference to the scope this node introduces.
    var innerScope: Scope? { get set }

}

/// Common interface for nodes associated with a name (symbol).
public protocol NamedNode: TypedNode {

    /// The name of symbol this node is associated with.
    var name: String { get }

    /// A reference to the scope defining the name of the symbol this node is associated with.
    var scope: Scope? { get }

    /// A reference to the symbol this node is associated with.
    var symbol: Symbol? { get }

}

extension NamedNode {

    public var symbol: Symbol? {
        return self.scope?[self.name].first
    }

    public var type: SemanticType? {
        get {
            return self.symbol?.type
        }

        set {
            if let newType = newValue {
                self.symbol!.type = newType
            }
        }
    }

}

// MARK: Scopes

/// An Anzen module.
///
/// This node represents an Anzen module (a.k.a. unit of compilation).
public class ModuleDecl: ScopeNode {

    public init(statements: [Node], location: SourceRange? = nil) {
        self.statements = statements
        self.location   = location
    }

    /// Stores the statements of the module.
    public var statements: [Node]

    // MARK: Annotations

    public var name      : String?
    public let location  : SourceRange?
    public var innerScope: Scope?

}

/// A block of statements.
///
/// This node represents a block of statements (e.g. a structure or function body).
public class Block: ScopeNode {

    public init(statements: [Node], location: SourceRange? = nil) {
        self.statements = statements
        self.location   = location
    }

    /// Stores the statements of the module.
    public var statements: [Node]

    // MARK: Annotations

    public let location  : SourceRange?
    public var innerScope: Scope?

}

// MARK: Declarations

/// A function declaration.
///
/// Function declarations are composed of a signature and a body. The former defines the domain and
/// codomain of the function, a set of type placeholders in the case it's generic, and an optional
/// set of conditions which further restrict its application domain.
///
/// Here's an example of a function declaration:
///
///     fun multiply(x: Int, by y: Int) -> Int {
///       return x * y
///     }
///
/// The domain of the function comprises two parameters `x` and `y`, both of type `Int`. Note that
/// the second parameter is associated with a label (named `by`). Both parameters are instances of
/// `ParamDecl`. The codomain is a type identifier, that is an instance of `Ident`.
///
/// - Note: While the body of a funtion declaration is represented by a `Block` node, the node
///   itself also conforms to `ScopeNode`. This is because function declarations open two scopes:
///   the first is for the function's signature and the second is for its body.
public class FunDecl: ScopeNode, NamedNode {

    public init(
        name        : String,
        attributes  : [FunctionAttribute] = [],
        placeholders: [String] = [],
        parameters  : [ParamDecl],
        codomain    : Node? = nil,
        body        : Block,
        location    : SourceRange? = nil)
    {
        self.name         = name
        self.attributes   = attributes
        self.placeholders = placeholders
        self.parameters   = parameters
        self.codomain     = codomain
        self.body         = body
        self.location     = location
    }

    /// The name of the function.
    public let name: String

    /// The attributes of the function.
    public let attributes: [FunctionAttribute]

    /// The generic placeholders of the function.
    public let placeholders: [String]

    /// The domain (i.e. parameters) of the function.
    public let parameters: [ParamDecl]

    /// The codomain of the function.
    ///
    /// Function codomains aren't restricted to type identifiers (i.e. instances of `Ident`). They
    /// can also be type signatures (e.g. `FunSign`) or even expressions (e.g. `BinExpr`). This is
    /// typically how functions that forward references are declared. For example:
    ///
    ///     fun min<T>(x: T, y: T) -> (x or y) where T is Comparable {
    ///       if x < y { return &- x } else { return &- y }
    ///     }
    ///
    /// Here the codomain is an instance of `BinExpr`.
    public let codomain: Node?

    /// The body of the function.
    public let body: Block

    // MARK: Annotations

    public let location  : SourceRange?
    public var scope     : Scope?
    public var innerScope: Scope?

    /// The symbol associated with the name of this function declaration.
    ///
    /// As function names might be overloaded, their symbols can't be identified by simply looking
    /// for that with the same name in the defining scope.
    public var symbol: Symbol?

}

/// A function parameter declaration.
public class ParamDecl: NamedNode {

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

    /// The label of the parameter.
    public let label: String?

    /// The name of the parameter.
    public let name: String

    /// The type annotation of the parameter.
    ///
    /// - Note: This must be either a type identifier (i.e. an instance of `Ident`), or a type
    ///   signature (i.e. an instance of `FunSign` or `StructSign`).
    public let typeAnnotation: Node

    // MARK: Annotations

    public let location  : SourceRange?
    public var scope     : Scope?
    public var qualifiers: Set<TypeQualifier> = []

}

/// A property declaration.
///
/// - Note: The term "property" can refer to variables, when declared within a function, or type
///   members, when declared within a type declaration (e.g. a structure). Unlike variables, type
///   members must be declared with either a type annotation or an initial binding value, so their
///   type can be inferred unambiguously.
public class PropDecl: NamedNode {

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

    /// The name of the property.
    public let name: String

    /// Whether or not the property is reassignable (i.e. declared with `var` or `let`).
    public let reassignable: Bool

    /// The type annotation of the property.
    ///
    /// - Note: This must be either a type identifier (i.e. an instance of `Ident`), or a type
    ///   signature (i.e. an instance of `QualSign`, `FunSign` or `StructSign`).
    public let typeAnnotation: Node?

    /// The initial binding value of the property.
    public let initialBinding: (op: Operator, value: Node)?

    // MARK: Annotations

    public let location  : SourceRange?
    public var scope     : Scope?
    public var qualifiers: Set<TypeQualifier> = []

}

/// A structure declaration.
///
/// Structures represent aggregate of properties (instances of `PropDecl`), and may be optionally
/// associated with operations (instances of `FunDecl`). We call the properties declared within a
/// structure its "members".
///
/// - Note: While the body of a structure declaration is represented by a `Block` node, the node
///   itself also conforms to `ScopeNode`. This is because structure declarations open two scopes:
///   the first is for the struct's signature and the second is for its body.
public class StructDecl: ScopeNode, NamedNode {

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

    /// The name of the type.
    public let name: String

    /// The generic placeholders of the type.
    public let placeholders: [String]

    /// The body of the type.
    ///
    /// - Note: The statements of a structure's body can only be instances `PropDecl` or `FunDecl`.
    public let body: Block

    // MARK: Annotations

    public let location  : SourceRange?
    public var scope     : Scope?
    public var innerScope: Scope?

}

/// An interface declaration.
///
/// Interfaces are blueprint of requirements (properties and methods) specifying how one can
/// interact with a type that conforms to (or implements) it.
///
/// - Note: While the body of an interface declaration is represented by a `Block` node, the node
///   itself also conforms to `ScopeNode`. This is because structure declarations open two scopes:
///   the first is for the interface's signature and the second is for its body.
public class InterfaceDecl: ScopeNode, NamedNode {

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

    /// The name of the type.
    public let name: String

    /// The generic placeholders of the type.
    public let placeholders: [String]

    /// The body of the type.
    ///
    /// - Note: The statements of an interface body can only be instances `PropReq` or `FunReq`.
    public let body: Block

    // MARK: Annotations

    public let location  : SourceRange?
    public var scope     : Scope?
    public var innerScope: Scope?

}

/// A property requirement declaration.
public class PropReq: NamedNode {

    public init(
        name          : String,
        reassignable  : Bool = false,
        typeAnnotation: Node,
        location      : SourceRange? = nil)
    {
        self.name           = name
        self.reassignable   = reassignable
        self.typeAnnotation = typeAnnotation
        self.location       = location
    }

    /// The name of the property.
    public let name: String

    /// Whether or not the property is reassignable (i.e. declared with `var` or `let`).
    public let reassignable: Bool

    /// The type annotation of the property.
    ///
    /// - Note: This must be either a type identifier (i.e. an instance of `Ident`), or a type
    ///   signature (i.e. an instance of `QualSign`, `FunSign` or `StructSign`).
    public let typeAnnotation: Node

    // MARK: Annotations

    public let location  : SourceRange?
    public var scope     : Scope?
    public var qualifiers: Set<TypeQualifier> = []

}

/// A method requirement declaration.
public class FunReq: ScopeNode, NamedNode {

    public init(
        name        : String,
        attributes  : [FunctionAttribute] = [],
        placeholders: [String] = [],
        parameters  : [ParamDecl],
        codomain    : Node? = nil,
        location    : SourceRange? = nil)
    {
        self.name         = name
        self.attributes   = attributes
        self.placeholders = placeholders
        self.parameters   = parameters
        self.codomain     = codomain
        self.location     = location
    }

    /// The name of the function.
    public let name: String

    /// The attributes of the function.
    public let attributes: [FunctionAttribute]

    /// The generic placeholders of the function.
    public let placeholders: [String]

    /// The domain (i.e. parameters) of the function.
    public let parameters: [ParamDecl]

    /// The codomain of the function.
    public let codomain: Node?

    // MARK: Annotations

    public let location  : SourceRange?
    public var scope     : Scope?
    public var innerScope: Scope?

    /// The symbol associated with the name of this function declaration.
    public var symbol: Symbol?

}

// MARK: Type signatures

/// A qualified type signature.
///
/// Qualified type signature comprise a semantic type definition (e.g. a type identifier) and a set
/// of type qualifiers.
public class QualSign: TypedNode {

    public init(
        qualifiers: Set<TypeQualifier>, signature: Node?, location: SourceRange? = nil)
    {
        self.qualifiers = qualifiers
        self.signature  = signature
        self.location   = location
    }

    /// The qualifiers of the signature.
    public let qualifiers: Set<TypeQualifier>

    /// The semantic type definition of the signature.
    ///
    /// - Note: This must be either a type identifier (i.e. an instance of `Ident`), or a semantic
    ///   type signature (i.e. an instance of `FunSign` or `StructSign`).
    public let signature : Node?

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : SemanticType?

}

/// A function type signature.
public class FunSign: TypedNode {

    public init(parameters: [ParamSign], codomain: Node, location: SourceRange? = nil) {
        self.parameters = parameters
        self.codomain   = codomain
        self.location   = location
    }

    /// The parameters of the signature.
    public let parameters: [ParamSign]

    /// The codomain of the signature.
    ///
    /// - Note: Unlike the signature of function declarations, function type signatures can't
    ///   feature expressions on their codomain, but only type defintiions. Hence this property
    ///   should be either a type identifier (i.e. an instance of `Ident`), or a semantic type
    ///   signature (i.e. an instance of `FunSign` or `StructSign`).
    public let codomain: Node

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : SemanticType?

}

/// A parameter of a function type signature.
public class ParamSign: TypedNode {

    public init(label: String?, typeAnnotation: Node, location: SourceRange? = nil) {
        self.label          = label
        self.typeAnnotation = typeAnnotation
        self.location       = location
    }

    /// The label of the parameter.
    public let label: String?

    /// The type annotation of the property.
    ///
    /// - Note: This must be either a type identifier (i.e. an instance of `Ident`), or a type
    ///   signature (i.e. an instance of `QualSign`, `FunSign` or `StructSign`).
    public let typeAnnotation: Node

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : SemanticType?

}

// MARK: Statements

/// A binding statement.
///
/// - Note: Binding statements are also sometimes referred to as assignments.
public class BindingStmt: Node {

    public init(lvalue: Node, op: Operator, rvalue: Node, location: SourceRange? = nil) {
        self.lvalue   = lvalue
        self.op       = op
        self.rvalue   = rvalue
        self.location = location
    }

    /// The lvalue of the binding.
    public let lvalue: Node

    /// The binding operator.
    public let op: Operator

    /// The rvalue of the binding.
    public let rvalue: Node

    // MARK: Annotations

    public let location: SourceRange?

}

/// A return statement.
public class ReturnStmt: Node {

    public init(value: Node? = nil, location: SourceRange? = nil) {
        self.value     = value
        self.location = location
    }

    /// The value of the return statement.
    public let value: Node?

    // MARK: Annotations

    public let location: SourceRange?

}

// MARK: Expressions

/// A condition expression.
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

    /// The condition of the expression.
    public let condition: Node

    /// The block of statements to execute if the condition is statisfied.
    public let thenBlock: Node

    /// The block of statements to execute if the condition isn't statisfied.
    public let elseBlock: Node?

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : SemanticType?

}

/// A binary expression.
public class BinExpr: TypedNode {

    public init(left: Node, op: Operator, right: Node, location: SourceRange? = nil) {
        self.left     = left
        self.op       = op
        self.right    = right
        self.location = location
    }

    /// The left operand of the expression.
    public let left : Node

    /// The operator of the expression.
    public let op: Operator

    /// The right operand of the expression.
    public let right: Node

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : SemanticType?

}

/// An unary expression.
public class UnExpr: TypedNode {

    public init(op: Operator, operand: Node, location: SourceRange? = nil) {
        self.op       = op
        self.operand  = operand
        self.location = location
    }

    /// The operator of the expression.
    public let op: Operator

    /// The left operand of the expression.
    public let operand: Node

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : SemanticType?

}

/// A call expression.
public class CallExpr: TypedNode {

    public init(callee: Node, arguments: [CallArg], location: SourceRange? = nil) {
        self.callee    = callee
        self.arguments = arguments
        self.location  = location
    }

    /// The callee.
    public let callee: Node

    /// The arguments of the call.
    public let arguments: [CallArg]

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : SemanticType?

}

/// A call argument.
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

    /// The label of the argument.
    public let label: String?

    /// The binding operator of the argument.
    public let bindingOp: Operator?

    /// The value of the argument.
    public let value: Node

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : SemanticType?

}

/// A subscript expression.
public class SubscriptExpr: TypedNode {

    public init(callee: Node, arguments: [CallArg], location: SourceRange? = nil) {
        self.callee    = callee
        self.arguments = arguments
        self.location  = location
    }

    /// The callee.
    public let callee: Node

    /// The arguments of the subscript.
    public let arguments: [CallArg]

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : SemanticType?

}

/// A select expression.
public class SelectExpr: TypedNode {

    public init(owner: Node? = nil, ownee: Ident, location: SourceRange? = nil) {
        self.owner    = owner
        self.ownee    = ownee
        self.location = location
    }

    /// The owner.
    public let owner: Node?

    /// The ownee.
    public let ownee: Ident

    // MARK: Annotations

    public let location: SourceRange?
    public var type    : SemanticType?

}

/// An identifier.
public class Ident: NamedNode {

    public init(
        name           : String,
        specializations: [String: Node] = [:],
        location       : SourceRange? = nil)
    {
        self.name            = name
        self.specializations = specializations
        self.location        = location
    }

    /// The name of the identifier.
    public let name: String

    /// The specialization list of the identifier.
    public let specializations: [String: Node]

    // MARK: Annotations

    public let location: SourceRange?
    public var scope   : Scope?

    /// The semantic type of this identifier.
    ///
    /// As an identifier might refer to an overloaded function, its type must be inferred before
    /// it can be associated with the correct symbol, once static dispatching has been performed.
    public var type: SemanticType?

    /// The symbol associated with the name of this identifier.
    ///
    /// As identifiers might refer to overloaded function names, their symbols can't be identified
    /// by simply looking for that with the same name in the defining scope.
    public var symbol: Symbol?

}

/// A literal expression.
public class Literal<T>: TypedNode {

    public init(value: T, location: SourceRange? = nil) {
        self.value    = value
        self.location = location
    }

    /// The value of the literal.
    public let value: T

    // MARK: Annotations

    public var type    : SemanticType?
    public let location: SourceRange?

}
