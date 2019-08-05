/// A module.
///
/// A module (a.k.a. a compilation unit) is an abstraction over multiple source files (a.k.a.
/// translation units) that are glued together. Hence a module is a collection of top-level
/// declarations (e.g. types and functions).
///
/// A module may contain a single "main" translation unit (named `main.anzen`, by convention) that
/// may contain top-level statements. These correspond to the statements of an implicit `main`
/// function. They are wrapped into a `MainCodeDecl` node by the parser.
public final class Module: DeclContext {

  public typealias ID = String

  /// A module's state.
  public enum State {
    /// Denotes a module that has not been parsed yet.
    case unparsed
    /// Denotes a module that has been parsed but not typed-checked yet.
    case parsed
    /// Denotes a fully type-checked module.
    case typeChecked
    /// Denotes a module that has been translated to AIR.
    case translated
  }

  public let parent: DeclContext? = nil
  public var children: [DeclContext] = []

  /// The module's identifier.
  public var id: ID
  /// The module's compilation state.
  public var state: State
  /// The top-level declarations of the module.
  public var decls: [Decl] = []

  public init(id: ID) {
    self.id = id
    self.state = .unparsed
  }

  // MARK: - Issues

  /// The list of issues that resulted from the processing of this module.
  public var issues: Set<Issue> = []

  // MARK: - Type constraints

  /// The list of type constraints collected before type inference.
  public var typeConstraints: [TypeConstraint] = []

}
