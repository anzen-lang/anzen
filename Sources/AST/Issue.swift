/// An alert raised during the processing of a module.
public struct Issue {

  /// Enumeration of issue severity levels.
  public enum SeverityLevel: Int {

    /// Denotes an issue that does not prevent compilation, but is indicative of either a possibly
    // erroneous situation, or a discouraged practice.
    case warning
    /// Denotes an issue that prevents compilation.
    case error

  }

  /// The severity of this issue.
  public let severity: SeverityLevel
  /// The issue's message.
  public let message: String
  /// The range in the source related to this issue.
  public let range: SourceRange
  /// The AST node related to this issue.
  public let node: ASTNode?

  public init(severity: SeverityLevel, message: String, range: SourceRange) {
    self.severity = severity
    self.message = message
    self.node = nil
    self.range = range
  }

  public init(severity: SeverityLevel, message: String, node: ASTNode) {
    self.severity = severity
    self.message = message
    self.node = node
    self.range = node.range
  }

  public static func < (lhs: Issue, rhs: Issue) -> Bool {
    if lhs.severity == rhs.severity {
      if lhs.range.sourceRef.name == rhs.range.sourceRef.name {
        return lhs.range.lowerBound < rhs.range.lowerBound
      } else {
        return lhs.range.sourceRef.name < rhs.range.sourceRef.name
      }
    } else {
      return lhs.severity.rawValue < rhs.severity.rawValue
    }
  }

}

extension Issue: Hashable {

  public static func == (lhs: Issue, rhs: Issue) -> Bool {
    return lhs.severity == rhs.severity
        && lhs.message == rhs.message
        && lhs.range == rhs.range
        && lhs.node === rhs.node
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(severity)
    hasher.combine(message)
    hasher.combine(range)
    if node != nil {
      hasher.combine(ObjectIdentifier(node!))
    }
  }

}
