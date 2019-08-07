import AST

/// A proxy to a named declaration.
public final class ProxiedNamedDecl: NamedDecl {

  // NamedDecl requirements

  public var name: String

  public var type: TypeBase? {
    return proxiedDecl.type
  }

  public weak var declContext: DeclContext? {
    get { return proxiedDecl.declContext }
    set { proxiedDecl.declContext = newValue }
  }

  public var module: Module {
    return proxiedDecl.module
  }

  public var range: SourceRange {
    get { return proxiedDecl.range }
    set { proxiedDecl.range = newValue }
  }

  /// The proxied named declaration.
  public var proxiedDecl: NamedDecl

  init(_ proxiedDecl: NamedDecl, name: String? = nil) {
    self.name = name ?? proxiedDecl.name
    self.proxiedDecl = proxiedDecl
  }

  public func accept<V>(visitor: V) where V : ASTVisitor {
    proxiedDecl.accept(visitor: visitor)
  }

  public func traverse<V>(with visitor: V) where V : ASTVisitor {
    proxiedDecl.traverse(with: visitor)
  }

  public func accept<T>(transformer: T) -> ASTNode where T : ASTTransformer {
    return proxiedDecl.accept(transformer: transformer)
  }

  public func traverse<T>(with transformer: T) -> ASTNode where T : ASTTransformer {
    proxiedDecl = proxiedDecl.accept(transformer: transformer) as! ProxiedNamedDecl
    return self
  }


}
