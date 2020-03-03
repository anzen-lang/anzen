import Utils

/// A module.
///
/// A module (a.k.a. a compilation unit in Clang/LLVM's parlance) is an abstraction over multiple
/// source files (a.k.a. translation units) that are glued together. Hence a module is a collection
/// of top-level declarations (e.g. types and functions).
///
/// A module may contain a single "main" translation unit (named `main.anzen`, by convention) that
/// may contain top-level statements. These correspond to the statements of an implicit `main`
/// function. They are wrapped into a `MainCodeDecl` node by the parser.
public final class Module: DeclContext {

  public typealias ID = String

  /// A module's state.
  public enum State: Equatable {
    /// Denotes a module that has been created but not loaded yet.
    case created
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

  /// The module's generation number.
  ///
  /// This property is used internally during semantic analysis.
  public let generation: Int

  /// The module's compilation state.
  public var state: State

  /// The top-level declarations of the module.
  public var decls: [Decl] = []

  /// Creates a new module.
  ///
  /// - Attention:
  ///   You should not create modules with this initializer directly, unless you know what you are
  ///   doing. Modules are meant to be created within a compiler context and loaded by going
  ///   through a specific sequence of compilation passes.
  public init(id: ID, generation: Int, state: State = .created) {
    self.id = id
    self.generation = generation
    self.state = state
  }

  // MARK: - Issues

  /// The list of issues that resulted from the processing of this module.
  public var issues: Set<Issue> = []

  // MARK: - Debugging

  /// Dumps all module declarations to the standard output.
  public func dump() {
    let buffer = StringBuffer()
    let dumper = ASTDumper(to: buffer)

    for decl in decls {
      decl.accept(visitor: dumper)
      buffer.write("\n")
    }

    print(buffer.value)
  }

  /// Dumps all module declarations to the given buffer.
  public func dump<T>(_ stream: inout T) where T: TextOutputStream {
    let buffer = StringBuffer()
    let dumper = ASTDumper(to: buffer)

    for decl in decls {
      decl.accept(visitor: dumper)
      buffer.write("\n")
    }

    stream.write(buffer.value)
  }

}
