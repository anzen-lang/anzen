/// An AST node that represents an unqualified type signature.
public protocol TypeSign: ASTNode {

  /// The type realized from this signature.
  var type: TypeBase? { get }

}

/// A qualified type signature.
///
/// Qualified type signatures comprise a semantic type definition (e.g. a type identifier) and a
/// set of type qualifiers.
public final class QualTypeSign: ASTNode {

  /// Node requirements

  public unowned let module: Module
  public var range: SourceRange

  /// The qualifiers of the signature.
  public var quals: TypeQualSet
  /// The semantic type definition of the signature.
  public var sign: TypeSign?
  /// The type realized from this signature.
  public var type: TypeBase?

  public init(quals: TypeQualSet, sign: TypeSign?, module: Module, range: SourceRange) {
    self.quals = quals
    self.sign = sign
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    sign?.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    sign = sign?.accept(transformer: transformer) as? TypeSign
    return self
  }

}

/// A type identifier.
public final class IdentSign: TypeSign {

  /// TypeSign requirements

  public var type: TypeBase?

  /// ASTNode requirements

  public unowned let module: Module
  public var range: SourceRange

  /// The name of the type.
  public var name: String
  /// The identifier's specialization arguments.
  public var specArgs: [String: QualTypeSign]
  /// The declaration that corresponds to this type identifier.
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

/// A nested type identifier.
public final class NestedIdentSign: TypeSign {

  /// TypeSign requirements

  public var type: TypeBase?

  /// ASTNode requirements

  public unowned let module: Module
  public var range: SourceRange

  /// The identifier's owning type.
  public var owner: TypeSign
  /// The nested identifier.
  public var ownee: IdentSign

  public init(owner: TypeSign, ownee: IdentSign, module: Module, range: SourceRange) {
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
    owner = owner.accept(transformer: transformer) as! IdentSign
    ownee = ownee.accept(transformer: transformer) as! IdentSign
    return self
  }

}

/// A nested type identifier with an implicit owning type.
public final class ImplicitNestedIdentSign: TypeSign {

  /// TypeSign requirements

  public var type: TypeBase?

  /// ASTNode requirements

  public unowned let module: Module
  public var range: SourceRange

  /// The nested identifier.
  public var ownee: IdentSign

  public init(ownee: IdentSign, module: Module, range: SourceRange) {
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
    ownee = ownee.accept(transformer: transformer) as! IdentSign
    return self
  }

}

/// An unqualified function type signature.
public final class FunSign: TypeSign {

  /// TypeSign requirements

  public var type: TypeBase?

  /// ASTNode requirements

  public unowned let module: Module
  public var range: SourceRange

  /// The function's domain (i.e. parameters' types).
  public var params: [ParamSign]
  /// The function's codomain (i.e. return type).
  public var codom: QualTypeSign?

  public init(params: [ParamSign], codom: QualTypeSign, module: Module, range: SourceRange) {
    self.params = params
    self.codom = codom
    self.module = module
    self.range = range
  }

  public func realizeType(in context: CompilerContext) -> TypeBase {
    // let from = params.map { FunType.Param(label: $0.label, type: $0.realizeType(in: context)) }
    fatalError()
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    params.forEach { $0.accept(visitor: visitor) }
    codom?.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    params = params.map { $0.accept(transformer: transformer) } as! [ParamSign]
    codom = codom?.accept(transformer: transformer) as? QualTypeSign
    return self
  }

}

/// A parameter of a function type signature.
public final class ParamSign: TypeSign {

  /// TypeSign requirements

  public var type: TypeBase?

  /// ASTNode requirements

  public unowned let module: Module
  public var range: SourceRange

  /// The parameter's label.
  public var label: String?
  /// The parameter's signature.
  public var sign: QualTypeSign

  public init(label: String?, sign: QualTypeSign, module: Module, range: SourceRange) {
    self.label = label
    self.sign = sign
    self.module = module
    self.range = range
  }

  public func accept<V>(visitor: V) where V: ASTVisitor {
    visitor.visit(self)
  }

  public func traverse<V>(with visitor: V) where V: ASTVisitor {
    sign.accept(visitor: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer {
    return transformer.transform(self)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer {
    sign = sign.accept(transformer: transformer) as! QualTypeSign
    return self
  }

}

/// An invalid type signature.
///
/// This type is for internal use only. It serves as a placeholder in other nodes for signatures
/// that couldn't not be parsed.
public final class InvalidSign: TypeSign {

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
