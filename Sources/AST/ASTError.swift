/// An error associated with an AST node.
public struct ASTError {

  public init(cause: Any, node: Node) {
    self.cause = cause
    self.node = node
  }

  public let cause: Any
  public let node: Node

}

public func < (lhs: ASTError, rhs: ASTError) -> Bool {
  let lname = lhs.node.module.id?.qualifiedName ?? ""
  let rname = rhs.node.module.id?.qualifiedName ?? ""
  return lname == rname
    ? lhs.node.range.start < rhs.node.range.start
    : lname < rname
}
