import Foundation

import AST
import Interpreter
import Parser
import Sema
import Utils

class Loader: ModuleLoader {

  func load(_ moduleID: ModuleIdentifier, in context: ASTContext) throws -> ModuleDecl {
    // Determine the filename of the module.
    let filename: String
    switch moduleID {
    case .builtin:
      filename = "builtin.anzen"
    case .stdlib:
      filename = "stdlib.anzen"
    case .local(name: let name):
      filename = "\(name).anzen"
    }

    for path in searchPaths {
      if let src = try? File(path: path + filename) {
        let module = try Parser(file: src).parse()
        module.id = moduleID

        // FIXME: To replace with `performSymbolBinding` and `performTypeInference`.
        for passType in passTypes {
          var pass = passType.init(context: context)
          try pass.visit(module)
        }

        // FIXME: To be properly implemented with a `--debug-type-inference` flag.
        if moduleID != .builtin && moduleID != .stdlib {
          Console.err.print("-- Constraints ----", in: .bold)
          for constraint in context.typeConstraints {
            constraint.prettyPrint()
          }
        }

        var solver = ConstraintSolver(constraints: context.typeConstraints, in: context)
        let result = solver.solve()
        switch result {
        case .success(let solution, _):
          var applier = TypeApplier(context: context, solution: solution)
          try applier.visit(module)

        case .failure(let errors):
          for error in errors {
            Console.err.print(error)
          }
        }

        context.typeConstraints.removeAll()

        // FIXME: To be properly implemented with a `--debug-type-inference` flag.
        if moduleID != .builtin && moduleID != .stdlib {
          Console.out.print()
          var printer = ASTPrinter(in: Console.out, includeType: true)
          try! printer.visit(module)
        }

        return module
      }
    }

    throw IOError.fileNotFound(path: filename)
  }

  let searchPaths = [
    "/Users/alvae/Developer/Anzen/micro-anzen/Sources/Core/",
    "/Users/alvae/Developer/Anzen/anzen/InputSamples/",
  ]

  let passTypes: [SAPass.Type] = [
    SymbolCreator.self,
    NameBinder.self,
    ConstraintCreator.self,
  ]

}

// ---

let loader = Loader()
let ctx = ASTContext(moduleLoader: loader)

let main = try loader.load(.local(name: "main"), in: ctx)

//Console.out.print()
//var printer = ASTPrinter(in: Console.out, includeType: true)
//try! printer.visit(main)

//// Interpret the AST.
//var interpreter = Interpreter()
//do {
//    try interpreter.execute(ast: module)
//} catch let error as RuntimeError {
//    reportExecutionError(error)
//    exit(-1)
//}
