/// An AST node that represents a statement.
public protocol Stmt: ASTNode {
}

/// A sequence of statements enclosed in braces.
public final class BraceStmt: Stmt, DeclContext {

  // Stmt requirements

  public unowned var module: Module
  public var range: SourceRange

  // DeclContext requirements

  public weak var parent: DeclContext?
  public var children: [DeclContext] = []

  /// The statements within this brace statement.
  public var stmts: [ASTNode]

  public init(stmts: [ASTNode], module: Module, range: SourceRange) {
    self.stmts = stmts
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    stmts.forEach { $0.accept(visitor: visitor) }
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    stmts = stmts.map { $0.accept(transformer: transformer) }
    return self
  }

}

/// A conditional statement.
public final class IfStmt: Stmt {

  // Stmt requirements

  public unowned var module: Module
  public var range: SourceRange

  /// The expression's condition.
  public var condition: Expr
  /// The statements to execute if the condition is statisfied.
  public var thenStmt: Stmt
  /// The statements to execute if the condition isn't statisfied.
  public var elseStmt: Stmt?

  public init(
    condition: Expr,
    thenStmt: Stmt,
    elseStmt: Stmt? = nil,
    module: Module,
    range: SourceRange)
  {
    self.condition = condition
    self.thenStmt = thenStmt
    self.elseStmt = elseStmt
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    condition.accept(visitor: visitor)
    thenStmt.accept(visitor: visitor)
    elseStmt?.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    condition = condition.accept(transformer: transformer) as! Expr
    thenStmt = thenStmt.accept(transformer: transformer) as! BraceStmt
    elseStmt = elseStmt?.accept(transformer: transformer) as? Stmt
    return self
  }

}

/// A while-loop.
public final class WhileStmt: Stmt {

  // Stmt requirements

  public unowned var module: Module
  public var range: SourceRange

  /// The loop's condition.
  public var condition: Expr
  /// The loop's body, to be executed as lonf as the condition is satisfied.
  public var body: Stmt

  public init(
    condition: Expr,
    body: Stmt,
    module: Module,
    range: SourceRange)
  {
    self.condition = condition
    self.body = body
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    condition.accept(visitor: visitor)
    body.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    condition = condition.accept(transformer: transformer) as! Expr
    body = body.accept(transformer: transformer) as! BraceStmt
    return self
  }

}

/// A binding statement (a.k.a. assignment statement).
public final class BindingStmt: Stmt {

  // Stmt requirements

  public unowned var module: Module
  public var range: SourceRange

  /// The binding's operator.
  public var op: IdentExpr
  /// The binding's l-value.
  public var lvalue: Expr
  /// The binding's r-value.
  public var rvalue: Expr

  public init(
    op: IdentExpr,
    lvalue: Expr,
    rvalue: Expr,
    module: Module,
    range: SourceRange)
  {
    self.op = op
    self.lvalue = lvalue
    self.rvalue = rvalue
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    op.accept(visitor: visitor)
    lvalue.accept(visitor: visitor)
    rvalue.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    op = op.accept(transformer: transformer) as! IdentExpr
    lvalue = lvalue.accept(transformer: transformer) as! Expr
    rvalue = rvalue.accept(transformer: transformer) as! Expr
    return self
  }

}

/// A return statement.
public final class ReturnStmt: Stmt {

  // Stmt requirements

  public unowned var module: Module
  public var range: SourceRange

  /// The return's binding.
  public var binding: (op: IdentExpr, value: Expr)?

  public init(
    binding: (op: IdentExpr, value: Expr)? = nil,
    module: Module,
    range: SourceRange)
  {
    self.binding = binding
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    binding.map { (op, value) in
      op.accept(visitor: visitor)
      value.accept(visitor: visitor)
    }
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    binding = binding.map { (op, value) in
      (op.accept(transformer: transformer) as! IdentExpr,
       value.accept(transformer: transformer) as! Expr)
    }
    return self
  }

}

/// An invalid statement.
///
/// This type is for internal use only. It serves as a placeholder in other nodes for statements
/// that couldn't not be parsed.
public final class InvalidStmt: Stmt {

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
