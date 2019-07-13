// MARK: Protocols

/// Common interface for all AST nodes.
///
/// An Abstract Syntax Tree (AST) is a tree representation of a source code. Each node represents a
/// particular construction (e.g. a variable declaration), with each child representing a sub-
/// construction (e.g. the name of the variable being declared). The term "abstract" denotes the
/// fact that concrete syntactic details such as spaces and line returns are *abstracted* away.
public class Node: Equatable {

  fileprivate init(module: ModuleDecl?, range: SourceRange) {
    self.module = module
    self.range = range
  }

  /// The module that contains the node.
  public weak var module: ModuleDecl!
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
    super.init(module: nil, range: range)
    self.module = self
  }

  /// List of the type declarations in the module.
  public var typeDecls: [NominalTypeDecl] {
    return statements.compactMap { $0 as? NominalTypeDecl }
  }

  /// List of the function declarations in the module.
  public var funDecls: [FunDecl] {
    return statements.compactMap { $0 as? FunDecl }
  }

  /// Type, property and function declarations in the module.
  ///
  /// - Warning: This property is initialized during semantic analysis.
  public var declarations: [Symbol: NamedDecl] = [:]

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

  public init(statements: [Node], module: ModuleDecl, range: SourceRange) {
    self.statements = statements
    super.init(module: module, range: range)
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

/// Enumeration of the different function kinds.
public enum FunctionKind: String {

  case regular
  case method
  case constructor
  case destructor

}

/// Base class for named declarations.
public class NamedDecl: Node {

  fileprivate init(name: String, module: ModuleDecl, range: SourceRange) {
    self.name = name
    super.init(module: module, range: range)
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
    typeAnnotation: QualTypeSign? = nil,
    initialBinding: (op: BindingOperator, value: Expr)? = nil,
    module: ModuleDecl,
    range: SourceRange)
  {
    self.attributes = attributes
    self.typeAnnotation = typeAnnotation
    self.initialBinding = initialBinding
    super.init(name: name, module: module, range: range)
  }

  /// The member attributes of the property.
  public var attributes: Set<MemberAttribute>
  /// The type annotation of the property.
  public var typeAnnotation: QualTypeSign?
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
    kind: FunctionKind = .regular,
    placeholders: [String] = [],
    parameters: [ParamDecl],
    codomain: Node? = nil,
    body: Block? = nil,
    module: ModuleDecl,
    range: SourceRange)
  {
    self.attributes = attributes
    self.kind = kind
    self.placeholders = placeholders
    self.parameters = parameters
    self.codomain = codomain
    self.body = body
    super.init(name: name, module: module, range: range)
  }

  /// The member attributes of the function.
  public var attributes: Set<MemberAttribute>
  /// The kind of the function.
  public var kind: FunctionKind
  /// The generic placeholders of the function.
  public var placeholders: [String]
  /// The domain (i.e. parameters) of the function.
  public var parameters: [ParamDecl]
  /// The codomain of the function.
  public var codomain: Node?
  /// The body of the function.
  public var body: Block?

  /// The scope delimited by this function.
  public var innerScope: Scope?
  /// The capture list of the function.
  public var captures: [Symbol] = []

}

/// A function parameter declaration.
public final class ParamDecl: NamedDecl {

  public init(
    label: String?,
    name: String,
    typeAnnotation: QualTypeSign? = nil,
    defaultValue: Expr? = nil,
    module: ModuleDecl,
    range: SourceRange)
  {
    self.label = label
    self.typeAnnotation = typeAnnotation
    self.defaultValue = defaultValue
    super.init(name: name, module: module, range: range)
  }

  /// The label of the parameter.
  public var label: String?
  /// The type annotation of the parameter.
  public var typeAnnotation: QualTypeSign?
  /// The default value of the parameter.
  public var defaultValue: Expr?

}

/// Base class for node representing a nominal type declaration.
public class NominalTypeDecl: NamedDecl, ScopeDelimiter {

  fileprivate init(
    name: String,
    body: Block,
    module: ModuleDecl,
    range: SourceRange)
  {
    self.body = body
    super.init(name: name, module: module, range: range)
  }

  /// The body of the type.
  public var body: Block
  /// The scope delimited by the type.
  public var innerScope: Scope?

}

/// A structure declaration.
///
/// Structures represent aggregate of properties and methods.
public final class StructDecl: NominalTypeDecl {

  public init(
    name: String,
    placeholders: [String] = [],
    body: Block,
    module: ModuleDecl,
    range: SourceRange)
  {
    self.placeholders = placeholders
    super.init(name: name, body: body, module: module, range: range)
  }

  /// The generic placeholders of the type.
  public var placeholders: [String]

}

/// An interface declaration.
///
/// Interfaces are blueprint of requirements (properties and methods) for types to conform to.
public final class InterfaceDecl: NominalTypeDecl {

  public init(
    name: String,
    placeholders: [String] = [],
    body: Block,
    module: ModuleDecl,
    range: SourceRange)
  {
    self.placeholders = placeholders
    super.init(name: name, body: body, module: module, range: range)
  }

  /// The generic placeholders of the type.
  public var placeholders: [String]

}

// MARK: Type signatures

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

/// A qualified type signature.
///
/// Qualified type signature comprise a semantic type definition (e.g. a type identifier) and a set
/// of type qualifiers.
public final class QualTypeSign: Node {

  public init(
    qualifiers: Set<TypeQualifier>,
    signature: Node?,
    module: ModuleDecl,
    range: SourceRange)
  {
    self.qualifiers = qualifiers
    self.signature = signature
    super.init(module: module, range: range)
  }

  /// The qualifiers of the signature.
  public var qualifiers: Set<TypeQualifier>

  /// The semantic type definition of the signature.
  ///
  /// - Note: This must be either a type identifier (i.e. an instance of `Ident`), or a semantic
  ///   type signature (i.e. an instance of `FunSign` or `StructSign`).
  public var signature: Node?

}

/// Base class for node representing an unqualified type signatures.
public class TypeSign: Node {

}

/// A type identifier.
public final class TypeIdent: TypeSign {

  public init(
    name: String,
    specializations: [String: QualTypeSign] = [:],
    module: ModuleDecl,
    range: SourceRange)
  {
    self.name = name
    self.specializations = specializations
    super.init(module: module, range: range)
  }

  /// The name of the type.
  public var name: String
  /// The specialization list of the type.
  public var specializations: [String: QualTypeSign]
  /// The symbol associated with the declaration.
  public var symbol: Symbol?
  /// The scope in which the declaration is defined.
  public var scope: Scope? { return symbol?.scope }

  /// The type of the identifier, which might differ from its symbol for generic types.
  public var type: TypeBase?

}

/// A function type signature.
public final class FunSign: TypeSign {

  public init(parameters: [ParamSign], codomain: Node, module: ModuleDecl, range: SourceRange) {
    self.parameters = parameters
    self.codomain = codomain
    super.init(module: module, range: range)
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

/// A parameter of a function type signature.
public final class ParamSign: TypeSign {

  public init(label: String?, typeAnnotation: Node, module: ModuleDecl, range: SourceRange) {
    self.label = label
    self.typeAnnotation = typeAnnotation
    super.init(module: module, range: range)
  }

  /// The label of the parameter.
  public var label: String?

  /// The type annotation of the property.
  ///
  /// - Note: This must be either a type identifier (i.e. an instance of `Ident`), or a type
  ///   signature (i.e. an instance of `QualTypeSign`, `TypeSign`).
  public var typeAnnotation: Node

}

// MARK: Statements

/// A while-loop.
public final class WhileLoop: Node {

  public init(
    condition: Expr,
    body: Block,
    module: ModuleDecl,
    range: SourceRange)
  {
    self.condition = condition
    self.body = body
    super.init(module: module, range: range)
  }

  /// The condition of the loop.
  public var condition: Expr
  /// The block of statements to execute as long as the condition is statisfied.
  public var body: Node

}

/// A binding statement.
///
/// - Note: Binding statements are also sometimes referred to as assignments.
public final class BindingStmt: Node {

  public init(
    lvalue: Expr,
    op: BindingOperator,
    rvalue: Expr,
    module: ModuleDecl,
    range: SourceRange)
  {
    self.lvalue = lvalue
    self.op = op
    self.rvalue = rvalue
    super.init(module: module, range: range)
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

  public init(
    binding: (op: BindingOperator, value: Expr)? = nil,
    module: ModuleDecl,
    range: SourceRange)
  {
    self.binding = binding
    super.init(module: module, range: range)
  }

  /// The binding of the return statement.
  public var binding: (op: BindingOperator, value: Expr)?

}

// MARK: Expressions

/// Base class for node representing an expression.
public class Expr: Node {

  /// The type of the expression.
  public var type: TypeBase?

}

/// A condition expression.
public final class IfExpr: Expr {

  public init(
    condition: Expr,
    thenBlock: Node,
    elseBlock: Node? = nil,
    module: ModuleDecl,
    range: SourceRange)
  {
    self.condition = condition
    self.thenBlock = thenBlock
    self.elseBlock = elseBlock
    super.init(module: module, range: range)
  }

  /// The condition of the expression.
  public var condition: Expr
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

  public init(
    parameters: [ParamDecl],
    codomain: Node? = nil,
    body: Block,
    module: ModuleDecl,
    range: SourceRange)
  {
    self.parameters = parameters
    self.codomain = codomain
    self.body = body
    super.init(module: module, range: range)
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

/// A cast expression.
public final class CastExpr: Expr {

  public init(operand: Expr, castType: TypeSign, module: ModuleDecl, range: SourceRange) {
    self.operand = operand
    self.castType = castType
    super.init(module: module, range: range)
  }

  /// The operand of the expression.
  public var operand: Expr
  /// The type it is cast to.
  public var castType: TypeSign

}

/// A binary expression.
public final class BinExpr: Expr {

  public init(left: Expr, op: InfixOperator, right: Expr, module: ModuleDecl, range: SourceRange) {
    self.left = left
    self.op = op
    self.right = right
    super.init(module: module, range: range)
  }

  /// The left operand of the expression.
  public var left : Expr
  /// The operator of the expression.
  public var op: InfixOperator
  /// The right operand of the expression.
  public var right: Expr

  /// The type of the operator.
  public var operatorType: TypeBase?

}

/// An unary expression.
public final class UnExpr: Expr {

  public init(op: PrefixOperator, operand: Expr, module: ModuleDecl, range: SourceRange) {
    self.op = op
    self.operand = operand
    super.init(module: module, range: range)
  }

  /// The operator of the expression.
  public var op: PrefixOperator
  /// The operand of the expression.
  public var operand: Expr

  /// The type of the operator.
  public var operatorType: TypeBase?

}

/// A call expression.
public final class CallExpr: Expr {

  public init(callee: Expr, arguments: [CallArg], module: ModuleDecl, range: SourceRange) {
    self.callee = callee
    self.arguments = arguments
    super.init(module: module, range: range)
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
    module: ModuleDecl,
    range: SourceRange)
  {
    self.label = label
    self.bindingOp = bindingOp
    self.value = value
    super.init(module: module, range: range)
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

  public init(callee: Node, arguments: [CallArg], module: ModuleDecl, range: SourceRange) {
    self.callee = callee
    self.arguments = arguments
    super.init(module: module, range: range)
  }

  /// The callee.
  public var callee: Node
  /// The arguments of the subscript.
  public var arguments: [CallArg]

}

/// A select expression.
public final class SelectExpr: Expr {

  public init(owner: Expr? = nil, ownee: Ident, module: ModuleDecl, range: SourceRange) {
    self.owner = owner
    self.ownee = ownee
    super.init(module: module, range: range)
  }

  /// The owner.
  public var owner: Expr?
  /// The ownee.
  public var ownee: Ident

}

/// An identifier.
public final class Ident: Expr {

  public init(
    name: String,
    specializations: [String: QualTypeSign] = [:],
    module: ModuleDecl,
    range: SourceRange)
  {
    self.name = name
    self.specializations = specializations
    super.init(module: module, range: range)
  }

  /// The name of the identifier.
  public var name: String
  /// The specialization list of the identifier.
  public var specializations: [String: QualTypeSign]
  /// The scope in which the identifier's defined.
  public var scope: Scope?

  /// The symbol associated with this identifier.
  ///
  /// Identifiers might refer to overloaded names. Hence, their symbol can't be determined during
  /// name binding, but should rather be resolved by static dispatching.
  public var symbol: Symbol?

}

/// An array literal expression.
public final class ArrayLiteral: Expr {

  public init(elements: [Expr], module: ModuleDecl, range: SourceRange) {
    self.elements = elements
    super.init(module: module, range: range)
  }

  /// The elements of the literal.
  public var elements: [Expr]

}

/// An set literal expression.
public final class SetLiteral: Expr {

  public init(elements: [Expr], module: ModuleDecl, range: SourceRange) {
    self.elements = elements
    super.init(module: module, range: range)
  }

  /// The elements of the literal.
  public var elements: [Expr]

}

/// An map literal expression.
public final class MapLiteral: Expr {

  public init(elements: [String: Expr], module: ModuleDecl, range: SourceRange) {
    self.elements = elements
    super.init(module: module, range: range)
  }

  /// The elements of the literal.
  public var elements: [String: Expr]

}

/// A scalar literal expression.
public final class Literal<T>: Expr {

  public init(value: T, module: ModuleDecl, range: SourceRange) {
    self.value = value
    super.init(module: module, range: range)
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

  public init(enclosing expression: Node, module: ModuleDecl, range: SourceRange) {
    self.expression = expression
    super.init(module: module, range: range)
  }

  /// The enclosed expression.
  public var expression: Node

}

/// An unparsable sequence of tokens in the source input.
///
/// The node is used by the parser to represent unparsable sequences of tokens.
public final class UnparsableInput: Node {

  public init(module: ModuleDecl, range: SourceRange) {
    super.init(module: module, range: range)
  }

}
