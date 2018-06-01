// MARK: Protocols

/// Common interface for all AST nodes.
///
/// An Abstract Syntax Tree (AST) is a tree representation of a source code. Each node represents a
/// particular construction (e.g. a variable declaration), with each child representing a sub-
/// construction (e.g. the name of the variable being declared). The term "abstract" denotes the
/// fact that concrete syntactic details such as spaces and line returns are *abstracted* away.
public class Node: Equatable {

  fileprivate init(range: SourceRange) {
    self.range = range
  }

  /// Stores the ranges in the source file of the concrete syntax this node represents.
  public var range: SourceRange

  public static func == (lhs: Node, rhs: Node) -> Bool {
    return lhs === rhs
  }

}

/// Protocol for nodes that delimit a scope.
public protocol ScopeDelimiter {

  /// The scope delimited by the node.
  var innerScope: Scope? { get set }

}

/// An Anzen module.
///
/// This node represents an Anzen module (a.k.a. unit of compilation).
public final class ModuleDecl: Node, ScopeDelimiter {

  public init(statements: [Node], range: SourceRange) {
    self.statements = statements
    super.init(range: range)
  }

  /// Looks up for a (possibly overloaded) declaration set at the module scope.
  public func lookupDecl(_ name: String) -> [Node] {
    return statements.filter { ($0 as? NamedDecl)?.name == name }
  }

  /// List of the top-level type declarations of the module.
  public var typeDecls: [NominalTypeDecl] {
    return statements.compactMap({ $0 as? NominalTypeDecl })
  }

  /// Stores the statements of the module.
  public var statements: [Node]

  /// The identifier of the module.
  public var id: ModuleIdentifier?
  /// The scope delimited by the module.
  public var innerScope: Scope?

}

/// A block of statements.
///
/// This node represents a block of statements (e.g. a structure or function body).
public final class Block: Node, ScopeDelimiter {

  public init(statements: [Node], range: SourceRange) {
    self.statements = statements
    super.init(range: range)
  }

  /// Stores the statements of the module.
  public var statements: [Node]

  /// The scope delimited by the block.
  public var innerScope: Scope?

}

// MARK: Declarations

/// Enumeration of the member attributes.
public enum MemberAttribute: String {

  case mutating
  case reassignable
  case `static`

}

/// Base class for named declarations.
public class NamedDecl: Node {

  fileprivate init(name: String, range: SourceRange) {
    self.name = name
    super.init(range: range)
  }

  /// The name of the declaration.
  public var name: String
  /// The symbol associated with the declaration.
  public var symbol: Symbol?
  /// The scope in which the declaration is defined.
  public var scope: Scope? { return symbol?.scope }
  /// The type of the declaration's symbol.
  public var type: TypeBase? { return symbol?.type }

}

/// A property declaration.
///
/// - Note: The term "property" can refer to variables, when declared within a function, or type
///   members, when declared within a type declaration (e.g. a structure). Unlike variables, type
///   members must be declared with either a type annotation or an initial binding value, so their
///   type can be inferred unambiguously.
public final class PropDecl: NamedDecl {

  public init(
    name: String,
    attributes: Set<MemberAttribute> = [],
    reassignable: Bool = false,
    typeAnnotation: QualSign? = nil,
    initialBinding: (op: BindingOperator, value: Expr)? = nil,
    range: SourceRange)
  {
    self.attributes = attributes
    self.reassignable = reassignable
    self.typeAnnotation = typeAnnotation
    self.initialBinding = initialBinding
    super.init(name: name, range: range)
  }

  /// The member attributes of the property.
  public var attributes: Set<MemberAttribute>
  /// Whether or not the property is reassignable (i.e. declared with `var` or `let`).
  public var reassignable: Bool
  /// The type annotation of the property.
  public var typeAnnotation: QualSign?
  /// The initial binding value of the property.
  public var initialBinding: (op: BindingOperator, value: Expr)?

}

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
public final class FunDecl: NamedDecl, ScopeDelimiter {

  public init(
    name: String,
    attributes: Set<MemberAttribute> = [],
    placeholders: [String] = [],
    parameters: [ParamDecl],
    codomain: Node? = nil,
    body: Block? = nil,
    range: SourceRange)
  {
    self.attributes = attributes
    self.placeholders = placeholders
    self.parameters = parameters
    self.codomain = codomain
    self.body = body
    super.init(name: name, range: range)
  }

  /// The member attributes of the function.
  public var attributes: Set<MemberAttribute>
  /// The generic placeholders of the function.
  public var placeholders: [String]
  /// The domain (i.e. parameters) of the function.
  public var parameters: [ParamDecl]
  /// The codomain of the function.
  public var codomain: Node?
  /// The body of the function.
  public var body: Block?

  /// The scope delimited by this module.
  public var innerScope: Scope?

}

/// A function parameter declaration.
public final class ParamDecl: NamedDecl {

  public init(
    label: String?,
    name: String,
    typeAnnotation: QualSign?,
    defaultValue: Expr? = nil,
    range: SourceRange)
  {
    self.label = label
    self.typeAnnotation = typeAnnotation
    self.defaultValue = defaultValue
    super.init(name: name, range: range)
  }

  /// The label of the parameter.
  public var label: String?
  /// The type annotation of the parameter.
  public var typeAnnotation: QualSign?
  /// The default value of the parameter.
  public var defaultValue: Expr?

}

/// Base class for node representing a nominal type declaration.
public class NominalTypeDecl: NamedDecl, ScopeDelimiter {

  fileprivate override init(name: String, range: SourceRange) {
    super.init(name: name, range: range)
  }

  /// The scope delimited by the type.
  public var innerScope: Scope?

}

/// A structure declaration.
///
/// Structures represent aggregate of properties and methods.
public final class StructDecl: NominalTypeDecl {

  public init(name: String, placeholders: [String] = [], body: Block, range: SourceRange) {
    self.placeholders = placeholders
    self.body = body
    super.init(name: name, range: range)
  }

  /// The generic placeholders of the type.
  public var placeholders: [String]
  /// The body of the type.
  public var body: Block

}

/// An interface declaration.
///
/// Interfaces are blueprint of requirements (properties and methods) for types to conform to.
public final class InterfaceDecl: NominalTypeDecl {

  public init(name: String, placeholders: [String] = [], body: Block, range: SourceRange) {
    self.placeholders = placeholders
    self.body = body
    super.init(name: name, range: range)
  }

  /// The generic placeholders of the type.
  public var placeholders: [String]
  /// The body of the type.
  public var body: Block

}

// MARK: Type signatures

/// A qualified type signature.
///
/// Qualified type signature comprise a semantic type definition (e.g. a type identifier) and a set
/// of type qualifiers.
public final class QualSign: Node {

  public init(qualifiers: Set<TypeQualifier>, signature: Node?, range: SourceRange) {
    self.qualifiers = qualifiers
    self.signature = signature
    super.init(range: range)
  }

  /// The qualifiers of the signature.
  public let qualifiers: Set<TypeQualifier>

  /// The semantic type definition of the signature.
  ///
  /// - Note: This must be either a type identifier (i.e. an instance of `Ident`), or a semantic
  ///   type signature (i.e. an instance of `FunSign` or `StructSign`).
  public let signature: Node?

}

/// A function type signature.
public final class FunSign: Node {

  public init(parameters: [ParamSign], codomain: Node, range: SourceRange) {
    self.parameters = parameters
    self.codomain = codomain
    super.init(range: range)
  }

  /// The parameters of the signature.
  public var parameters: [ParamSign]

  /// The codomain of the signature.
  ///
  /// - Note: Unlike the signature of function declarations, function type signatures can't feature
  ///   expressions on their codomain, but only type defintiions. Hence this property should be
  ///   either a type identifier (i.e. an instance of `Ident`), or a semantic type signature (i.e.
  ///   an instance of `FunSign` or `StructSign`).
  public var codomain: Node

}

/// Enumeration of the type qualifiers.
public enum TypeQualifier: CustomStringConvertible {

  case cst, mut

  public var description: String {
    switch self {
    case .cst: return "@cst"
    case .mut: return "@mut"
    }
  }

}

/// A parameter of a function type signature.
public final class ParamSign: Node {

  public init(label: String?, typeAnnotation: Node, range: SourceRange) {
    self.label = label
    self.typeAnnotation = typeAnnotation
    super.init(range: range)
  }

  /// The label of the parameter.
  public var label: String?

  /// The type annotation of the property.
  ///
  /// - Note: This must be either a type identifier (i.e. an instance of `Ident`), or a type
  ///   signature (i.e. an instance of `QualSign`, `FunSign` or `StructSign`).
  public var typeAnnotation: Node

}

// MARK: Statements

/// A binding statement.
///
/// - Note: Binding statements are also sometimes referred to as assignments.
public final class BindingStmt: Node {

  public init(lvalue: Expr, op: BindingOperator, rvalue: Expr, range: SourceRange) {
    self.lvalue = lvalue
    self.op = op
    self.rvalue = rvalue
    super.init(range: range)
  }

  /// The lvalue of the binding.
  public var lvalue: Expr
  /// The binding operator.
  public var op: BindingOperator
  /// The rvalue of the binding.
  public var rvalue: Expr

}

/// A return statement.
public final class ReturnStmt: Node {

  public init(value: Node? = nil, range: SourceRange) {
    self.value = value
    super.init(range: range)
  }

  /// The value of the return statement.
  public var value: Node?

}

// MARK: Expressions

/// Base class for node representing an expression.
public class Expr: Node {

  /// The type of the expression.
  public var type: TypeBase?

}

/// A condition expression.
public final class IfExpr: Expr {

  public init(condition: Node, thenBlock: Node, elseBlock: Node? = nil, range: SourceRange) {
    self.condition = condition
    self.thenBlock = thenBlock
    self.elseBlock = elseBlock
    super.init(range: range)
  }

  /// The condition of the expression.
  public var condition: Node
  /// The block of statements to execute if the condition is statisfied.
  public var thenBlock: Node
  /// The block of statements to execute if the condition isn't statisfied.
  public var elseBlock: Node?

}

/// A lambda expression.
///
/// Lambda expressions are very similar to function declarations, except that they are anonymous,
/// and can't feature place holders.
public final class LambdaExpr: Expr {

  public init(parameters: [ParamDecl], codomain: Node? = nil, body: Block, range: SourceRange) {
    self.parameters = parameters
    self.codomain = codomain
    self.body = body
    super.init(range: range)
  }

  /// The domain (i.e. parameters) of the lambda.
  public var parameters: [ParamDecl]

  /// The codomain of the lambda.
  ///
  /// Function codomains aren't restricted to qualified types. They may also be represented by
  /// expressions (e.g. `BinExpr`). This is typically how functions that forward references are
  /// declared. For example:
  ///
  ///     fun min<T>(x: T, y: T) -> (x or y) where T is Comparable {
  ///       if x < y { return &- x } else { return &- y }
  ///     }
  ///
  /// Here the codomain is an instance of `BinExpr`.
  public var codomain: Node?

  /// The body of the lambda.
  public var body: Block

}

/// A binary expression.
public final class BinExpr: Expr {

  public init(left: Node, op: InfixOperator, right: Node, range: SourceRange) {
    self.left = left
    self.op = op
    self.right = right
    super.init(range: range)
  }

  /// The left operand of the expression.
  public var left : Node
  /// The operator of the expression.
  public var op: InfixOperator
  /// The right operand of the expression.
  public var right: Node

}

/// An unary expression.
public final class UnExpr: Expr {

  public init(op: PrefixOperator, operand: Node, range: SourceRange) {
    self.op = op
    self.operand = operand
    super.init(range: range)
  }

  /// The operator of the expression.
  public var op: PrefixOperator
  /// The operand of the expression.
  public var operand: Node

}

/// A call expression.
public final class CallExpr: Expr {

  public init(callee: Expr, arguments: [CallArg], range: SourceRange) {
    self.callee = callee
    self.arguments = arguments
    super.init(range: range)
  }

  /// The callee.
  public var callee: Expr
  /// The arguments of the call.
  public var arguments: [CallArg]

}

/// A call argument.
public final class CallArg: Expr {

  public init(
    label: String? = nil,
    bindingOp: BindingOperator = .copy,
    value: Expr,
    range: SourceRange)
  {
    self.label = label
    self.bindingOp = bindingOp
    self.value = value
    super.init(range: range)
  }

  /// The label of the argument.
  public var label: String?
  /// The binding operator of the argument.
  public var bindingOp: BindingOperator
  /// The value of the argument.
  public var value: Expr

}

/// A subscript expression.
public final class SubscriptExpr: Expr {

  public init(callee: Node, arguments: [CallArg], range: SourceRange) {
    self.callee = callee
    self.arguments = arguments
    super.init(range: range)
  }

  /// The callee.
  public var callee: Node
  /// The arguments of the subscript.
  public var arguments: [CallArg]

}

/// A select expression.
public final class SelectExpr: Expr {

  public init(owner: Node? = nil, ownee: Ident, range: SourceRange) {
    self.owner = owner
    self.ownee = ownee
    super.init(range: range)
  }

  /// The owner.
  public var owner: Node?
  /// The ownee.
  public var ownee: Ident

}

/// An identifier.
public final class Ident: Expr {

  public init(
    name: String,
    specializations: [String: Node] = [:],
    range: SourceRange)
  {
    self.name = name
    self.specializations = specializations
    super.init(range: range)
  }

  /// The name of the identifier.
  public var name: String
  /// The specialization list of the identifier.
  public var specializations: [String: Node]

  /// The scope in which the identifier's defined.
  public var scope: Scope?

}

/// An array literal expression.
public final class ArrayLiteral: Expr {

  public init(elements: [Node], range: SourceRange) {
    self.elements = elements
    super.init(range: range)
  }

  /// The elements of the literal.
  public var elements: [Node]

}

/// An set literal expression.
public final class SetLiteral: Expr {

  public init(elements: [Node], range: SourceRange) {
    self.elements = elements
    super.init(range: range)
  }

  /// The elements of the literal.
  public var elements: [Node]

}

/// An map literal expression.
public final class MapLiteral: Expr {

  public init(elements: [String: Node], range: SourceRange) {
    self.elements = elements
    super.init(range: range)
  }

  /// The elements of the literal.
  public var elements: [String: Node]

}

/// A scalar literal expression.
public final class Literal<T>: Expr {

  public init(value: T, range: SourceRange) {
    self.value = value
    super.init(range: range)
  }

  /// The value of the literal.
  public var value: T

}

/// An enclosed expression.
///
/// This represents an expression enclosed within parenthesis. It's an internal type of node whose
/// sole purpose is for operator precedence to be properly parsed. It should be removed during the
/// AST sanitizing phase.
public final class EnclosedExpr: Expr {

  public init(enclosing expression: Node, range: SourceRange) {
    self.expression = expression
    super.init(range: range)
  }

  /// The enclosed expression.
  var expression: Node

}