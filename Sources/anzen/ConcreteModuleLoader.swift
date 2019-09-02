import AST
import Parser
import Sema
import SystemKit
import Utils

public struct ConcreteModuleLoader: ModuleLoader {

  public func load(module: Module, fromDirectory dir: Path, in context: CompilerContext)
    throws -> Module
  {
    // Parse the module.
    assert(module.state == .created, "Module '\(module.id)' already loaded")
    let it = try dir.makeDirectoryIterator()
    while let filepath = it.next() {
      let isMainCodeDecl = filepath.filename == "main.swift"

      let buffer = TextFile(path: filepath)
      let source = SourceRef(name: String(filepath.filename!), buffer: buffer)
      let parser = try Parser(source: source, module: module, isMainCodeDecl: isMainCodeDecl)
      let (decls, issues) = parser.parse()
      module.decls.append(contentsOf: decls)
      module.issues.formUnion(issues)
    }

    // Check that the AST is well-formed.
    ParseFinalizerPass(module: module).process()
    module.state = .parsed

    // Perform semantic analysis on the module.
    NameBinderPass(module: module, context: context).process()
    TypeRealizerPass(module: module, context: context).process()
    TypeCheckerPass(module: module, context: context).process()
    CaptureAnalysisPass(module: module, context: context).process()
    module.state = .typeChecked

    return module
  }

  public func load(module: Module, fromText buffer: TextInputBuffer, in context: CompilerContext)
    throws -> Module
  {
    fatalError("not implemented")
  }

}
