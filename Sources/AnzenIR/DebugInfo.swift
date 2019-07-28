import AST

/// An aggregate of metadata for debugging at runtime.
public typealias DebugInfo = [DebugInfoKey: Any]

/// The key of a debug metadata.
public enum DebugInfoKey {

  /// The range in the Anzen source corresponding to a given AIR construct.
  case range

  /// The name in the Anzen source corresponding to a given AIR construct.
  case name

  /// The original Anzen type of the reference corresponding to a given AIR construct.
  case anzenType

  /// The callee of a call expression.
  case callee

  /// The operand of an unary expression.
  case operand

  /// The left operand of a binary expression of assignment statement.
  case lhs

  /// The right operand of a binary expression of assignment statement.
  case rhs

}

// MARK: Debug info builders

extension Node {

  var debugInfo: DebugInfo {
    var metadata: DebugInfo = [.range: range]

    if let this = self as? PropDecl {
      metadata[.name] = this.name
      if let (_, value) = this.initialBinding {
        metadata[.rhs] = value.debugInfo
      }
    }

    if let this = self as? BindingStmt {
      metadata[.lhs] = this.lvalue.debugInfo
      metadata[.rhs] = this.rvalue.debugInfo
    }

    if let this = self as? Expr {
      if let type = this.type {
        metadata[.anzenType] = type
      }

      if let this = self as? CastExpr {
        metadata[.operand] = this.operand.debugInfo
      }

      if let this = self as? CallExpr {
        metadata[.callee] = this.callee.debugInfo
      }

      if let this = self as? CallArg {
        metadata[.rhs] = this.value.debugInfo
      }

      if let this = self as? Ident {
        metadata[.name] = this.name
      }
    }

    return metadata
  }

}
