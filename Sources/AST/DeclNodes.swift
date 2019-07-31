/// An AST node that represents the declaration (a.k.a. definition) of an entity.
public protocol Decl: ASTNode {

  /// This entity's declaration context.
  var declContext: DeclContext? { get }

}

/// A node that represents a named declaration (a.k.a. definition).
public protocol NamedDecl: Decl {

  /// The declared entity's name.
  var name: String { get }
  /// This declared entity's type.
  var type: TypeBase? { get }
  /// Whether this declaration is overloadable.
  var isOverloadable: Bool { get }

}

extension NamedDecl {

  public var isOverloadable: Bool { return false }

}

/// A declaration node that wraps top-level statements of the main translation unit.
public final class MainCodeDecl: Decl, DeclContext {

  // Decl requirements

  public weak var declContext: DeclContext?
  public unowned var module: Module
  public var range: SourceRange

  // DeclContext requirements

  public var parent: DeclContext? { return declContext }
  public var children: [DeclContext] = []

  /// The translation unit's statements.
  public var stmts: [ASTNode]

  public init(stmts: [ASTNode] = [], module: Module, range: SourceRange) {
    self.stmts = stmts
    self.declContext = module
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

/// A declaration attribute.
public enum DeclAttr {

  /// Denotes a mutating function.
  case `mutating`
  /// Denotes a reassignable property.
  case reassignable
  /// Denotes a static function or property.
  case `static`

}

/// A property (i.e. a variable or type field) declaration.
public final class PropDecl: NamedDecl, Stmt {

  // NamedDecl requirements

  public var name: String
  public var type: TypeBase?
  public weak var declContext: DeclContext?
  public unowned var module: Module
  public var range: SourceRange

  /// The property's attributes.
  public var attrs: Set<DeclAttr>
  /// The property's type signature.
  public var sign: QualTypeSign?
  /// The property's initial binding.
  public var initializer: (op: Ident, value: Expr)?

  public init(
    name: String,
    attrs: Set<DeclAttr> = [],
    sign: QualTypeSign? = nil,
    initializer: (op: Ident, value: Expr)? = nil,
    declContext: DeclContext,
    module: Module,
    range: SourceRange)
  {
    self.name = name
    self.attrs = attrs
    self.sign = sign
    self.initializer = initializer
    self.module = module
    self.range = range
    self.declContext = declContext
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    sign?.accept(visitor: visitor)
    initializer.map { (op, value) in
      op.accept(visitor: visitor)
      value.accept(visitor: visitor)
    }
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    sign = sign?.accept(transformer: transformer) as? QualTypeSign
    initializer = initializer.map { (op, value) in
      (op.accept(transformer: transformer) as! Ident,
       value.accept(transformer: transformer) as! Expr)
    }
    return self
  }

}

/// A function declaration.
///
/// Function declarations are composed of a signature and a body. The former defines the domain and
/// codomain of the function, a sequence of generic parameters in the case it's generic, and an
/// optional set of conditions which further restrict its application domain.
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
public final class FunDecl: NamedDecl, Stmt, DeclContext {

  /// A function kind.
  public enum Kind {

    /// Denotes a regular function.
    case regular
    /// Denotes a method.
    case method
    /// Denotes a type constructor.
    case constructor
    /// Denotes a type desctructor.
    case destructor

  }

  // NamedDecl requirements

  public var isOverloadable: Bool {
    return kind != .destructor
  }

  public var name: String
  public var type: TypeBase?
  public weak var declContext: DeclContext?
  public unowned var module: Module
  public var range: SourceRange

  // DeclContext requirements

  public var parent: DeclContext? { return declContext }
  public var children: [DeclContext] = []

  /// The compiler directives associated with the function.
  public var directives: [Directive]
  /// The function's attributes.
  public var attrs: Set<DeclAttr>
  /// The function's kind.
  public var kind: Kind
  /// The function's generic parameters.
  public var genericParams: [GenericParamDecl]
  /// The function's parameters.
  public var params: [ParamDecl]
  /// The function's codomain (i.e. return type).
  public var codom: QualTypeSign?
  /// The function's body.
  public var body: BraceStmt?

  public init(
    name: String,
    directives: [Directive] = [],
    attrs: Set<DeclAttr> = [],
    kind: Kind = .regular,
    genericParams: [GenericParamDecl] = [],
    params: [ParamDecl] = [],
    codom: QualTypeSign? = nil,
    body: BraceStmt? = nil,
    declContext: DeclContext,
    module: Module,
    range: SourceRange)
  {
    self.name = name
    self.directives = directives
    self.attrs = attrs
    self.kind = kind
    self.genericParams = genericParams
    self.params = params
    self.codom = codom
    self.body = body
    self.declContext = declContext
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    directives.forEach { $0.accept(visitor: visitor) }
    genericParams.forEach { $0.accept(visitor: visitor) }
    params.forEach { $0.accept(visitor: visitor) }
    codom?.accept(visitor: visitor)
    body?.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    directives = directives.map { $0.accept(transformer: transformer) } as! [Directive]
    genericParams = genericParams.map { $0.accept(transformer: transformer) }
      as! [GenericParamDecl]
    params = params.map { $0.accept(transformer: transformer) } as! [ParamDecl]
    codom = codom?.accept(transformer: transformer) as? QualTypeSign
    body = body?.accept(transformer: transformer) as? BraceStmt
    return self
  }

}

/// A generic parameter declaration.
public final class GenericParamDecl: NamedDecl {

  // NamedDecl requirements

  public var name: String
  public var type: TypeBase?
  public weak var declContext: DeclContext?
  public unowned var module: Module
  public var range: SourceRange

  public init(name: String, declContext: DeclContext, module: Module, range: SourceRange) {
    self.name = name
    self.declContext = declContext
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

/// A function parameter declaration.
public final class ParamDecl: NamedDecl {

  // NamedDecl requirements

  public var name: String
  public var type: TypeBase?
  public weak var declContext: DeclContext?
  public unowned var module: Module
  public var range: SourceRange

  /// The parameter's label.
  public var label: String?
  /// The parameter's type signature.
  public var sign: QualTypeSign?
  /// The parameter's default value.
  public var defaultValue: Expr?

  public init(
    label: String? = nil,
    name: String,
    sign: QualTypeSign? = nil,
    defaultValue: Expr? = nil,
    declContext: DeclContext,
    module: Module,
    range: SourceRange)
  {
    self.label = label
    self.name = name
    self.sign = sign
    self.defaultValue = defaultValue
    self.declContext = declContext
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    sign?.accept(visitor: visitor)
    defaultValue?.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    sign = sign?.accept(transformer: transformer) as? QualTypeSign
    return self
  }

}

public class NominalTypeDecl: NamedDecl, DeclContext {

  // NamedDecl requirements

  public var name: String
  public var type: TypeBase?
  public weak var declContext: DeclContext?
  public unowned var module: Module
  public var range: SourceRange

  // DeclContext requirements

  public var parent: DeclContext? { return declContext }
  public var children: [DeclContext] = []

  /// The type's generic parameters.
  public var genericParams: [GenericParamDecl]
  /// The type declaration's body.
  public var body: BraceStmt?

  public init(
    name: String,
    genericParams: [GenericParamDecl] = [],
    body: BraceStmt? = nil,
    declContext: DeclContext,
    module: Module,
    range: SourceRange)
  {
    self.name = name
    self.genericParams = genericParams
    self.body = body
    self.declContext = declContext
    self.module = module
    self.range = range
  }

}

/// An interface declaration.
///
/// Interfaces are blueprint of requirements (properties and methods) for types to conform to.
public final class InterfaceDecl: NominalTypeDecl {

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    genericParams.forEach { $0.accept(visitor: visitor) }
    body?.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    genericParams = genericParams.map { $0.accept(transformer: transformer) }
      as! [GenericParamDecl]
    body = body?.accept(transformer: transformer) as? BraceStmt
    return self
  }

}

/// A structure declaration.
///
/// Structures represent aggregate of properties and methods.
public final class StructDecl: NominalTypeDecl {

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    genericParams.forEach { $0.accept(visitor: visitor) }
    body?.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    genericParams = genericParams.map { $0.accept(transformer: transformer) }
      as! [GenericParamDecl]
    body = body?.accept(transformer: transformer) as? BraceStmt
    return self
  }

}

/// A union declaration.
///
/// Union types (a.k.a. sum types) are types that can have several separate representations, in
/// contrast to structures (a.k.a. product types) which represent aggregates of properties.
public final class UnionDecl: NominalTypeDecl {

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    genericParams.forEach { $0.accept(visitor: visitor) }
    body?.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    genericParams = genericParams.map { $0.accept(transformer: transformer) }
      as! [GenericParamDecl]
    body = body?.accept(transformer: transformer) as? BraceStmt
    return self
  }

}

/// A union nested member declaration.
public final class UnionNestedMemberDecl: ASTNode {

  // Node requirements

  public unowned var module: Module
  public var range: SourceRange

  /// The member's type declaration.
  public var nominalTypeDecl: NominalTypeDecl

  public init(nominalTypeDecl: NominalTypeDecl, module: Module, range: SourceRange) {
    self.nominalTypeDecl = nominalTypeDecl
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    nominalTypeDecl.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    nominalTypeDecl = nominalTypeDecl.accept(transformer: transformer) as! NominalTypeDecl
    return self
  }

}
