import SystemKit
import Utils

/// A module loader.
///
/// The compiler context abstracts over the implementation of module loading, and delegates this
/// task to module loaders.
public protocol ModuleLoader {

  /// Load a module from a directory.
  ///
  /// This method will merge fetch source files (i.e. `.anzen` files) **directly** under the given
  /// directory, merge them in a single compilation unit and compile them as a module.
  @discardableResult
  func load(module: Module, fromDirectory: Path, in: CompilerContext) throws -> Module

  /// Loads a single translation unit as a module from a text buffer.
  @discardableResult
  func load(module: Module, fromText: TextInputBuffer, in: CompilerContext) throws -> Module

}
