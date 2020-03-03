import SystemKit

import AST
import Parser
import Sema
import Utils

/// An instance of the Anzen compiler/interpreter.
public class Anzen {

  /// The compiler's context.
  public let context: CompilerContext

  /// Initializes a new compiler instance.
  public init() {
    context = CompilerContext()

    // Create the built-in module.
    let builtin = Module(id: "__Builtin", generation: 0, state: .typeChecked)
    for name in BuiltinTypeName.allCases {
      let decl = BuiltinTypeDecl(name: name.rawValue, module: builtin)
      decl.type = BuiltinType(decl: decl, context: context)
      decl.declContext = builtin
      builtin.decls.append(decl)
    }
    context.modules["__Builtin"] = builtin
  }

  /// Creates an empty module.
  public func createModule(named name: String) -> (created: Bool, module: Module) {
    // Check if the module already exists.
    if let module = context.modules[name] {
      return (false, module)
    }

    // Create a new module.
    context.currentGeneration = context.currentGeneration + 1
    let module = Module(id: name, generation: context.currentGeneration)

    context.modules[name] = module
    return (true, module)
  }

  /// Loads the given path as a module.
  ///
  /// If the
  /// This method merges all source files (i.e. `.anzen` files) directly under `directory` into a
  /// single compilation unit, that is loaded into the compiler's context as a module.
  ///
  /// - Parameters:
  ///   - path: The directory from which source files should be read.
  ///   - name: The name of the module.
  ///
  ///     If this parameter is not provided, the module will be named after the given path by
  ///     default (e.g. if `path` is `/Some/Path/Foo.anezn` the module will be named `Foo`). In
  ///     this case, `path` must a path to a file or to a named directory.
  ///
  /// - Returns:
  ///   `(true, module)` if the compiler hasn't already loaded a module with the same name, where
  ///   `module` is the loaded module. Otherwise, the metod returns `(false, oldModule)`, where
  ///   `oldModule` is the module with the same name that has already been loaded.
  @discardableResult
  public func loadModule(
    fromPath path: Path,
    withName name: String? = nil
  ) throws -> (created: Bool, module: Module) {
    // Generate a module ID unless one has been provided.
    let moduleID: String! = name ?? path.filename.map({ filename in
      filename.hasSuffix(".anzen")
        ? String(filename.dropLast(6))
        : String(filename)
    })

    // Check if the module already exists.
    if let module = context.modules[moduleID] {
      return (false, module)
    }

    // Create a new module.
    context.currentGeneration = context.currentGeneration + 1
    let module = Module(id: moduleID, generation: context.currentGeneration)
    context.modules[moduleID] = module

    do {
      // Try to open the given path as a file.
      let buffer = try TextFile(path: path).read()
      try parse(buffer, asMain: path.filename == "main.anzen", into: module)
    } catch {
      // Try to open the given path as a directory.
      let iter = try path.makeDirectoryIterator()
      let subpaths = AnySequence<Path>({ iter })
      for subpath in subpaths where subpath.fileExtension == "anzen" {
        try parse(TextFile(path: subpath), asMain: subpath.filename == "main.anzen", into: module)
      }
    }

    // Compile and load the module.
    try compile(module)
    return (true, module)
  }

  /// Loads the given text buffer as a module.
  ///
  /// This method uses the given text buffer as a compilation unit, that is loaded into the
  /// compiler's context as a module.
  ///
  /// - Parameters:
  ///   - buffer: A text buffer containing the source of the compilation unit to load.
  ///   - isMainCodeDecl: A flag that indicates whether the module is an entry point.
  ///   - name: The name of the module.
  ///
  /// - Returns:
  ///   `(true, module)` if the compiler hasn't already loaded a module with the same name, where
  ///   `module` is the loaded module. Otherwise, the metod returns `(false, oldModule)`, where
  ///   `oldModule` is the module with the same name that has already been loaded.
  @discardableResult
  public func loadModule(
    fromText buffer: TextInputBuffer,
    asMain isMainCodeDecl: Bool = false,
    withName name: String
  ) throws -> (created: Bool, module: Module) {
    // Check if the module already exists.
    if let module = context.modules[name] {
      return (false, module)
    }

    // Create a new module.
    context.currentGeneration = context.currentGeneration + 1
    let module = Module(id: name, generation: context.currentGeneration)
    context.modules[name] = module

    // Parse the given translation unit.
    try parse(buffer, asMain: isMainCodeDecl, into: module)

    // Compile and load the module.
    try compile(module)
    return (true, module)
  }

  /// Parses declarations from a text buffer into the given module.
  ///
  /// - Parameters:
  ///   - buffer: A text buffer representing the translation unit to parse.
  ///   - isMainCodeDecl: A flag that indicates whether the buffer should be parsed as is a main
  ///     code declaration.
  ///   - module: The module into which the parsed declarations should be merged.
  public func parse(
    _ buffer: TextInputBuffer,
    asMain isMainCodeDecl: Bool = false,
    into module: Module
  ) throws {
    // Parse the given translation unit.
    let source = SourceRef(name: module.id, buffer: buffer)
    let parser = try Parser(source: source, module: module, isMainCodeDecl: isMainCodeDecl)
    let (decls, issues) = parser.parse()

    // Store all parsing issues into the module object.
    module.decls.append(contentsOf: decls)
    module.issues.formUnion(issues)
  }

  /// Compiles the given module.
  public func compile(_ module: Module) throws {
    // Check that the AST is well-formed.
    ParseFinalizerPass(module: module).process()
    module.state = .parsed

    // Perform semantic analysis on the module.
    NameBinderPass(module: module, context: context).process()
    TypeRealizerPass(module: module, context: context).process()
    TypeCheckerPass(module: module, context: context).process()
    CaptureAnalysisPass(module: module, context: context).process()
    module.state = .typeChecked
  }

}
