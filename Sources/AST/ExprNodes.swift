/// A node that represents an expression.
public protocol Expr: ASTNode {

  /// The expression's type.
  var type: TypeBase? { get set }

}

/// A null reference.
public final class NullExpr: Expr {

  // Expr requirements

  public var type: TypeBase?
  public unowned var module: Module
  public var range: SourceRange

  public init(module: Module, range: SourceRange) {
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    return self
  }

}

/// A lambda expression (a.k.a. anonymous function).
public final class LambdaExpr: Expr {

  // Expr requirements

  public var type: TypeBase?
  public unowned var module: Module
  public var range: SourceRange

  /// The function's parameters.
  public var params: [ParamDecl]
  /// The function's codomain (i.e. return type).
  public var codom: QualTypeSign?
  /// The function's body.
  public var body: BraceStmt

  public init(
    params: [ParamDecl],
    codom: QualTypeSign? = nil,
    body: BraceStmt,
    module: Module,
    range: SourceRange)
  {
    self.params = params
    self.codom = codom
    self.body = body
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    params.forEach { $0.accept(visitor: visitor) }
    codom?.accept(visitor: visitor)
    body.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    params = params.map { $0.accept(transformer: transformer) } as! [ParamDecl]
    codom = codom?.accept(transformer: transformer) as! QualTypeSign
    body = body.accept(transformer: transformer) as! BraceStmt
    return self
  }

}

/// An unsafe cast expression.
public final class UnsafeCastExpr: Expr {

  // Expr requirements

  public var type: TypeBase?
  public unowned var module: Module
  public var range: SourceRange

  /// The expression's operand.
  public var operand: Expr
  /// The signature of the type to which the expression should cast.
  public var castSign: TypeSign

  public init(operand: Expr, castSign: TypeSign, module: Module, range: SourceRange) {
    self.operand = operand
    self.castSign = castSign
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<Visitor>(with visitor: V) where V: ASTVisitor {
    operand.accept(visitor: visitor)
    castSign.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    operand = operand.accept(transformer: transformer) as! Expr
    castSign = castSign.accept(transformer: transformer) as! QualTypeSign
    return self
  }

}

/// An infix expression.
public final class InfixExpr: Expr {

  // Expr requirements

  public var type: TypeBase?
  public unowned var module: Module
  public var range: SourceRange

  /// The expression's operator.
  public var op: Ident
  /// The expression's left operand.
  public var left: Expr
  /// The expression's right operand.
  public var right: Expr

  public init(op: Ident, left: Expr, right: Expr, module: Module, range: SourceRange) {
    self.op = op
    self.left = left
    self.right = right
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    op.accept(visitor: visitor)
    left.accept(visitor: visitor)
    right.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    op = op.accept(transformer: transformer) as! Ident
    left = left.accept(transformer: transformer) as! Expr
    right = right.accept(transformer: transformer) as! Expr
    return self
  }

}

/// A prefix expression.
public final class PrefixExpr: Expr {

  // Expr requirements

  public var type: TypeBase?
  public unowned var module: Module
  public var range: SourceRange

  /// The expression's operator.
  public var op: Ident
  /// The expression's operand.
  public var operand : Expr

  public init(op: Ident, operand: Expr, right: Expr, module: Module, range: SourceRange) {
    self.op = op
    self.operand = operand
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    op.accept(visitor: visitor)
    operand.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    op = op.accept(transformer: transformer) as! Ident
    operand = operand.accept(transformer: transformer) as! Expr
    return self
  }

}

/// A call expression.
public final class CallExpr: Expr {

  // Expr requirements

  public var type: TypeBase?
  public unowned var module: Module
  public var range: SourceRange

  /// The expression's callee.
  public var callee: Expr
  /// The arguments of the call.
  public var args: [CallArg]

  public init(callee: Expr, args: [CallArg], module: Module, range: SourceRange) {
    self.callee = callee
    self.args = args
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    callee.accept(visitor: visitor)
    args.forEach { $0.accept(visitor: visitor) }
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    callee = callee.accept(transformer: transformer) as! Expr
    args = args.map { $0.accept(transformer: transformer) } as! [CallArg]
    return self
  }

}

/// A call argument.
public final class CallArg: Expr {

  // Expr requirements

  public var type: TypeBase?
  public unowned var module: Module
  public var range: SourceRange

  /// The label of the argument.
  public var label: String?
  /// The binding operator of the argument.
  public var op: Ident
  /// The value of the argument.
  public var value: Expr

  public init(label: String? = nil, op: Ident, value: Expr, module: Module, range: SourceRange) {
    self.label = label
    self.op = op
    self.value = value
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    op.accept(visitor: visitor)
    value.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    op = op.accept(transformer: transformer) as! Ident
    value = value.accept(transformer: transformer) as! Expr
    return self
  }

}

/// An identifier.
public final class Ident: Expr {

  // Expr requirements

  public var type: TypeBase?
  public unowned var module: Module
  public var range: SourceRange

  /// The name of the identifier.
  public var name: String
  /// The identifier's specialization arguments.
  public var specArgs: [String: QualTypeSign]
  /// The declaration context in which the identifier's defined.
  public var declContext: DeclContext?
  /// The declaration that corresponds to this identifier.
  public var decl: NamedDecl?

  public init(
    name: String,
    specArgs: [String: QualTypeSign] = [:],
    module: Module,
    range: SourceRange)
  {
    self.name = name
    self.specArgs = specArgs
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    specArgs.values.forEach { $0.accept(visitor: visitor) }
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    specArgs = Dictionary(uniqueKeysWithValues: specArgs.map { (name, arg) in
      (name, arg.accept(transformer: transformer) as! QualTypeSign)
    })
    return self
  }

}

/// A select expression.
public final class SelectExpr: Expr {

  // Expr requirements

  public var type: TypeBase?
  public unowned var module: Module
  public var range: SourceRange

  /// The expression's owner.
  public var owner: Expr
  /// The expression's ownee.
  public var ownee: Ident

  public init(owner: Expr, ownee: Ident, module: Module, range: SourceRange) {
    self.owner = owner
    self.ownee = ownee
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    owner.accept(visitor: visitor)
    ownee.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    owner = owner.accept(transformer: transformer) as! Expr
    ownee = ownee.accept(transformer: transformer) as! Ident
    return self
  }

}

/// A select expression with an implicit owning expression.
public final class ImplicitSelectExpr: Expr {

  // Expr requirements

  public var type: TypeBase?
  public unowned var module: Module
  public var range: SourceRange

  /// The expression's ownee.
  public var ownee: Ident

  public init(ownee: Ident, module: Module, range: SourceRange) {
    self.ownee = ownee
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    ownee.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    ownee = ownee.accept(transformer: transformer) as! Ident
    return self
  }

}

/// An array literal expression.
public final class ArrayLitExpr: Expr {

  // Expr requirements

  public var type: TypeBase?
  public unowned var module: Module
  public var range: SourceRange

  /// The elements of the literal.
  public var elements: [Expr]

  public init(elements: [Expr], module: Module, range: SourceRange) {
    self.elements = elements
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    elements.forEach { $0.accept(visitor: visitor) }
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    elements = elements.map { $0.accept(transformer: transformer) } as! [Expr]
    return self
  }

}

/// An set literal expression.
public final class SetLitExpr: Expr {

  // Expr requirements

  public var type: TypeBase?
  public unowned var module: Module
  public var range: SourceRange

  /// The elements of the literal.
  public var elements: [Expr]

  public init(elements: [Expr], module: Module, range: SourceRange) {
    self.elements = elements
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    elements.forEach { $0.accept(visitor: visitor) }
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    elements = elements.map { $0.accept(transformer: transformer) } as! [Expr]
    return self
  }

}

/// An map literal expression.
public final class MapLitExpr: Expr {

  // Expr requirements

  public var type: TypeBase?
  public unowned var module: Module
  public var range: SourceRange

  /// The elements of the literal.
  public var elements: [String: Expr]

  public init(elements: [String: Expr], module: Module, range: SourceRange) {
    self.elements = elements
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    elements.values.forEach { $0.accept(visitor: visitor) }
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    elements = Dictionary(uniqueKeysWithValues: elements.map { (key, value) in
      (key, value.accept(transformer: transformer) as! Expr)
    })
    return self
  }

}

/// A boolean literal expression.
public final class BoolLitExpr: Expr {

  // Expr requirements

  public var type: TypeBase?
  public unowned var module: Module
  public var range: SourceRange

  /// The value of the literal.
  public var value: Bool

  public init(value: Bool, module: Module, range: SourceRange) {
    self.value = value
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    return self
  }

}

/// An integer literal expression.
public final class IntLitExpr: Expr {

  // Expr requirements

  public var type: TypeBase?
  public unowned var module: Module
  public var range: SourceRange

  /// The value of the literal.
  public var value: Int

  public init(value: Int, module: Module, range: SourceRange) {
    self.value = value
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    return self
  }

}

/// A float literal expression.
public final class FloatLitExpr: Expr {

  // Expr requirements

  public var type: TypeBase?
  public unowned var module: Module
  public var range: SourceRange

  /// The value of the literal.
  public var value: Double

  public init(value: Double, module: Module, range: SourceRange) {
    self.value = value
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    return self
  }

}

/// A string literal expression.
public final class StringLitExpr: Expr {

  // Expr requirements

  public var type: TypeBase?
  public unowned var module: Module
  public var range: SourceRange

  /// The value of the literal.
  public var value: String

  public init(value: String, module: Module, range: SourceRange) {
    self.value = value
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    return self
  }

}

/// An expression enclosed in parenthesis.
///
/// This type is for internal use only, in order to parse operator precedence correctly.
public final class EnclosedExpr: Expr {

  // Expr requirements

  public var type: TypeBase?
  public unowned var module: Module
  public var range: SourceRange

  /// The enclosed expression.
  public var expr: Expr

  public init(enclosing expr: Expr, module: Module, range: SourceRange) {
    self.expr = expr
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    expr.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    expr = expr.accept(transformer: transformer) as! Expr
    return self
  }

}
