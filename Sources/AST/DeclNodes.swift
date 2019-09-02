/// An AST node that represents the declaration (a.k.a. definition) of an entity.
public protocol Decl: ASTNode {
}

/// A node that represents a named declaration (a.k.a. definition).
public protocol NamedDecl: Decl {

  /// This entity's declaration context.
  var declContext: DeclContext? { get set }

  /// The declared entity's name.
  var name: String { get }

  /// Whether this declaration is overloadable.
  var isOverloadable: Bool { get }

}

extension NamedDecl {

  public var isOverloadable: Bool { return false }

}

/// A node that represents the declaration of an l-value.
public protocol LValueDecl {

  /// The entity's semantic type.
  var type: QualType? { get set }

}

/// A node that represents a type declaration.
public protocol TypeDecl: ASTNode {

  /// The semantic type corresponding to the declaration.
  var type: TypeBase? { get }

}

public typealias NamedTypeDecl = NamedDecl & TypeDecl

/// A declaration node that wraps top-level statements of the main translation unit.
public final class MainCodeDecl: Decl, DeclContext {

  // Decl requirements

  public unowned var module: Module
  public var range: SourceRange

  // DeclContext requirements

  public var parent: DeclContext? { return module }
  public var decls: [Decl] = []

  /// The translation unit's statements.
  public var stmts: [ASTNode]

  public init(stmts: [ASTNode] = [], module: Module, range: SourceRange) {
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

/// A declaration attribute's declaration.
public final class DeclAttrDecl: ASTNode, Hashable {

  // ASTNode requirements

  public unowned var module: Module
  public var range: SourceRange

  /// The attribute's name.
  public var name: String
  /// The attribute's arguments.
  public var args: [String]

  public init(name: String, args: [String] = [], module: Module, range: SourceRange) {
    self.name = name
    self.args = args
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V : ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V : ASTVisitor {
  }

  public func accept<T>(transformer: T) -> ASTNode where T : ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T : ASTTransformer {
    return self
  }

  /// Hashable requirements

  public static func == (lhs: DeclAttrDecl, rhs: DeclAttrDecl) -> Bool {
    return (lhs.name == rhs.name) && (lhs.args == rhs.args)
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(name)
    hasher.combine(args)
  }

}

/// A declaration modifier's declaration.
public final class DeclModifierDecl: ASTNode, Hashable {

  /// Enumeration of the declaration modifier kinds.
  public enum Kind: Int {

    /// Denotes a static function or property.
    case `static`
    /// Denotes a mutating computed property.
    case `mutating`

  }

  // ASTNode requirements

  public unowned var module: Module
  public var range: SourceRange

  /// The modifier's kind.
  public var kind: Kind

  public init(kind: Kind, module: Module, range: SourceRange) {
    self.kind = kind
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V : ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V : ASTVisitor {
  }

  public func accept<T>(transformer: T) -> ASTNode where T : ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T : ASTTransformer {
    return self
  }

  /// Hashable requirements

  public static func == (lhs: DeclModifierDecl, rhs: DeclModifierDecl) -> Bool {
    return lhs.kind == rhs.kind
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(kind.rawValue)
  }

}

/// A property (i.e. a variable or type field) declaration.
public final class PropDecl: NamedDecl, LValueDecl, Stmt {

  // NamedDecl requirements

  public var name: String
  public weak var declContext: DeclContext?
  public unowned var module: Module
  public var range: SourceRange

  // LValueDecl requirements

  public var type: QualType?

  /// Whether the property's reassignable.
  public var isReassignable: Bool
  /// The property's declaration attributes.
  public var attrs: Set<DeclAttrDecl>
  /// The property's declaration modifiers.
  public var modifiers: Set<DeclModifierDecl>
  /// The property's type signature.
  public var sign: QualTypeSign?
  /// The property's initial binding.
  public var initializer: (op: IdentExpr, value: Expr)?

  public init(
    name: String,
    isReassignable: Bool = false,
    attrs: Set<DeclAttrDecl> = [],
    modifiers: Set<DeclModifierDecl> = [],
    sign: QualTypeSign? = nil,
    initializer: (op: IdentExpr, value: Expr)? = nil,
    module: Module,
    range: SourceRange)
  {
    self.name = name
    self.isReassignable = isReassignable
    self.attrs = attrs
    self.modifiers = modifiers
    self.sign = sign
    self.initializer = initializer
    self.module = module
    self.range = range
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
      (op.accept(transformer: transformer) as! IdentExpr,
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
public final class FunDecl: NamedDecl, LValueDecl, Stmt, DeclContext {

  /// Enumeration of the function kinds.
  public enum Kind: Int {

    /// Denotes a regular function.
    case regular     = 1
    /// Denotes a method.
    case method      = 2
    /// Denotes a type constructor.
    case constructor = 4
    /// Denotes a type desctructor.
    case destructor  = 8

    public static func ~= (lhs: Kind, rhs: [Kind]) -> Bool {
      return (lhs.rawValue & rhs.reduce(0) { $0 | $1.rawValue }) != 0
    }

  }

  // NamedDecl requirements

  public var isOverloadable: Bool {
    return kind != .destructor
  }

  public var name: String
  public weak var declContext: DeclContext?
  public unowned var module: Module
  public var range: SourceRange

  // DeclContext requirements

  public var parent: DeclContext? { return declContext }
  public var decls: [Decl] = []

  // LValueDecl requirements

  public var type: QualType?

  /// The declarations brought into the function's closure.
  public var capturedDecls: [NamedDecl] = []

  /// The function's declaration attributes.
  public var attrs: Set<DeclAttrDecl>

  /// The function's declaration modifiers.
  public var modifiers: Set<DeclModifierDecl>

  /// The function's kind.
  public var kind: Kind

  /// The function's generic parameters.
  public var genericParams: [GenericParamDecl]

  /// The function's parameters.
  public var params: [ParamDecl]

  /// The function's codomain (i.e. return type).
  public var codom: QualTypeSign?

  /// The function's body.
  public var body: Stmt?

  /// Whether the declaration denotes a mutating method.
  public var isMutating: Bool {
    return attrs.contains { $0.name == "mutating" }
  }

  /// Whether the declaration denotes a static method.
  public var isStatic: Bool {
    return attrs.contains { $0.name == "static" }
  }

  public init(
    name: String,
    attrs: Set<DeclAttrDecl> = [],
    modifiers: Set<DeclModifierDecl> = [],
    kind: Kind = .regular,
    genericParams: [GenericParamDecl] = [],
    params: [ParamDecl] = [],
    codom: QualTypeSign? = nil,
    body: Stmt? = nil,
    module: Module,
    range: SourceRange)
  {
    self.name = name
    self.attrs = attrs
    self.modifiers = modifiers
    self.kind = kind
    self.genericParams = genericParams
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
    genericParams.forEach { $0.accept(visitor: visitor) }
    params.forEach { $0.accept(visitor: visitor) }
    codom?.accept(visitor: visitor)
    body?.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    genericParams = genericParams.map { $0.accept(transformer: transformer) }
      as! [GenericParamDecl]
    params = params.map { $0.accept(transformer: transformer) } as! [ParamDecl]
    codom = codom?.accept(transformer: transformer) as? QualTypeSign
    body = body?.accept(transformer: transformer) as? Stmt
    return self
  }

}

/// A generic parameter declaration.
public final class GenericParamDecl: NamedDecl, TypeDecl {

  // NamedDecl requirements

  public var name: String
  public weak var declContext: DeclContext?
  public unowned var module: Module
  public var range: SourceRange

  // TypeDecl requirements

  /// The semantic type corresponding to the declaration. This must be a type placeholder.
  public var type: TypeBase? {
    didSet { assert((type == nil) || (type is TypePlaceholder)) }
  }

  public init(name: String, module: Module, range: SourceRange) {
    self.name = name
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
public final class ParamDecl: NamedDecl, LValueDecl {

  // NamedDecl requirements

  public var name: String
  public weak var declContext: DeclContext?
  public unowned var module: Module
  public var range: SourceRange

  // LValueDecl requirements

  public var type: QualType?

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
    module: Module,
    range: SourceRange)
  {
    self.label = label
    self.name = name
    self.sign = sign
    self.defaultValue = defaultValue
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

/// A nominal or built-in type declaration.
public protocol NominalOrBuiltinTypeDecl: NamedDecl, TypeDecl, DeclContext {

  /// The type's generic parameters.
  var genericParams: [GenericParamDecl] { get }

  /// The type declaration's body.
  var body: BraceStmt? { get }

  /// The member lookup table of this type.
  ///
  /// This table is populated during various passes of the semantic analysis for fast name lookup
  /// of the member's properties, methods and nested types.
  var memberLookupTable: MemberLookupTable? { get set }

}

/// An interface declaration.
///
/// Interfaces are blueprint of requirements (properties and methods) for types to conform to.
public final class InterfaceDecl: NominalOrBuiltinTypeDecl {

  // NominalOrBuiltinTypeDecl requirements

  public var genericParams: [GenericParamDecl]
  public var body: BraceStmt?
  public var memberLookupTable: MemberLookupTable?

  // NamedDecl requirements

  public var name: String
  public weak var declContext: DeclContext?
  public unowned var module: Module
  public var range: SourceRange

  // TypeDecl requirements

  public var type: TypeBase?

  // DeclContext requirements

  public var parent: DeclContext? { return declContext }
  public var decls: [Decl] = []

  public init(
    name: String,
    genericParams: [GenericParamDecl] = [],
    body: BraceStmt?,
    module: Module,
    range: SourceRange)
  {
    self.name = name
    self.genericParams = genericParams
    self.body = body
    self.module = module
    self.range = range
  }

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
public final class StructDecl: NominalOrBuiltinTypeDecl {

  // NominalOrBuiltinTypeDecl requirements

  public var genericParams: [GenericParamDecl]
  public var body: BraceStmt?
  public var memberLookupTable: MemberLookupTable?

  // NamedDecl requirements

  public var name: String
  public weak var declContext: DeclContext?
  public unowned var module: Module
  public var range: SourceRange

  // TypeDecl requirements

  public var type: TypeBase?

  // DeclContext requirements

  public var parent: DeclContext? { return declContext }
  public var decls: [Decl] = []

  public init(
    name: String,
    genericParams: [GenericParamDecl] = [],
    body: BraceStmt?,
    module: Module,
    range: SourceRange)
  {
    self.name = name
    self.genericParams = genericParams
    self.body = body
    self.module = module
    self.range = range
  }

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
public final class UnionDecl: NominalOrBuiltinTypeDecl {

  // NominalOrBuiltinTypeDecl requirements

  public var genericParams: [GenericParamDecl]
  public var body: BraceStmt?
  public var memberLookupTable: MemberLookupTable?

  // NamedDecl requirements

  public var name: String
  public weak var declContext: DeclContext?
  public unowned var module: Module
  public var range: SourceRange

  // TypeDecl requirements

  public var type: TypeBase?

  // DeclContext requirements

  public var parent: DeclContext? { return declContext }
  public var decls: [Decl] = []

  public init(
    name: String,
    genericParams: [GenericParamDecl] = [],
    body: BraceStmt?,
    module: Module,
    range: SourceRange)
  {
    self.name = name
    self.genericParams = genericParams
    self.body = body
    self.module = module
    self.range = range
  }

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

/// A union type case declaration.
public final class UnionTypeCaseDecl: Decl {

  // ASTNode requirements

  public unowned var module: Module
  public var range: SourceRange

  /// The member's type declaration.
  public var nestedDecl: NominalOrBuiltinTypeDecl

  public init(nestedDecl: NominalOrBuiltinTypeDecl, module: Module, range: SourceRange) {
    self.nestedDecl = nestedDecl
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    nestedDecl.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    nestedDecl = nestedDecl.accept(transformer: transformer) as! NominalOrBuiltinTypeDecl
    return self
  }

}

/// A union alias case declaration.
public final class UnionAliasCaseDecl: NamedTypeDecl {

  // TypeDecl requirements

  public var type: TypeBase?

  // NamedDecl requirements

  public var name: String
  public weak var declContext: DeclContext?
  public unowned var module: Module
  public var range: SourceRange

  /// The declaration to which this identifier refers.
  public var referredDecl: (NamedDecl & TypeDecl)?

  public init(name: String, module: Module, range: SourceRange) {
    self.name = name
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

/// A type extension declaration.
public final class TypeExtDecl: Decl, DeclContext {

  // Decl requirements

  public var module: Module
  public var range: SourceRange

  // DeclContext requirements

  public var parent: DeclContext?
  public var decls: [Decl] = []

  /// The signature of the type being extended. This should represent a nominal type.
  public var extTypeSign: TypeSign

  /// The extensions's body.
  public var body: Stmt

  public init(type: TypeSign, body: Stmt, module: Module, range: SourceRange) {
    self.extTypeSign = type
    self.body = body
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    extTypeSign.accept(visitor: visitor)
    body.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    extTypeSign = extTypeSign.accept(transformer: transformer) as! TypeSign
    body = body.accept(transformer: transformer) as! Stmt
    return self
  }

}

/// A built-in type declaration.
public final class BuiltinTypeDecl: NominalOrBuiltinTypeDecl {

  // NominalOrBuiltinTypeDecl requirements

  public var genericParams: [GenericParamDecl]
  public let body: BraceStmt? = nil
  public var memberLookupTable: MemberLookupTable?

  // NamedDecl requirements

  public var name: String
  public weak var declContext: DeclContext?
  public unowned var module: Module
  public var range: SourceRange

  // TypeDecl requirements

  public var type: TypeBase?

  // DeclContext requirements

  public var parent: DeclContext? { return declContext }
  public var decls: [Decl] = []

  public init(name: String, genericParams: [GenericParamDecl] = [], module: Module) {
    self.name = name
    self.genericParams = genericParams
    self.module = module

    let loc = SourceLocation(sourceRef: BuiltinTypeDecl.source)
    self.range = loc ..< loc
  }

  private static let source = SourceRef(name: "Builtin", buffer: "")

  public func accept<V>(visitor: V) where V : ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V : ASTVisitor {
  }

  public func accept<T>(transformer: T) -> ASTNode where T : ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T : ASTTransformer {
    return self
  }

}
