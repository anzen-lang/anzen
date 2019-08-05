import SystemKit

/// An AST node.
///
/// An Abstract Syntax Tree (AST) is a tree representation of a source code. Each node represents a
/// particular construction (e.g. a variable declaration), with each child representing a sub-
/// construction (e.g. the name of the variable being declared). The term "abstract" denotes the
/// fact that concrete syntactic details such as spaces and line returns are *abstracted* away.
public protocol ASTNode: AnyObject {

  /// The module that contains the node.
  var module: Module { get }
  /// The range in the source file of the concrete syntax representing this node.
  var range: SourceRange { get set }

  /// Accepts an AST visitor.
  func accept<V>(visitor: V) where V: ASTVisitor
  /// Forwards the given visitor to this node's children.
  func traverse<V>(with visitor: V) where V: ASTVisitor
  /// Accepts an AST transformer.
  func accept<T>(transformer: T) -> ASTNode where T: ASTTransformer
  /// Forwards the given transformer to this node's children.
  func traverse<T>(with transformer: T) -> ASTNode where T: ASTTransformer

}

extension ASTNode {

  /// Registers an error on this node.
  @discardableResult
  public func registerError(message: String) -> Issue {
    let newIssue = Issue(severity: .error, message: message, node: self)
    let (_, issue) = module.issues.insert(newIssue)
    return issue
  }

  /// Registers a warning on this node.
  @discardableResult
  public func registerWarning(message: String) -> Issue {
    let newIssue = Issue(severity: .warning, message: message, node: self)
    let (_, issue) = module.issues.insert(newIssue)
    return issue
  }

  public func dump() {
    let dumper = ASTDumper(to: System.err)
    accept(visitor: dumper)
    System.err.write("\n")
  }

}

/// A directive annotation.
///
/// A directive is an annotation that isn't related to the semantic of the code, but rather gives
/// provides the compiler with additional metadata to be used during compilation. For instance, a
/// directive can be specified on a function declaration to prevent name mangling.
public final class Directive: ASTNode {

  public unowned var module: Module
  public var range: SourceRange
  public var type: TypeBase?

  /// The name of the directive.
  public var name: String
  /// The arguments of the directive.
  public var args: [String]

  public init(name: String, args: [String], module: Module, range: SourceRange) {
    self.name = name
    self.args = args
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
