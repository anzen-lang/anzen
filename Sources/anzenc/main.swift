import Foundation
import AnzenLib
import AnzenSema

enum CommandError: Error {
    case missingInput
}

func main(args: [String] = CommandLine.arguments) throws {
    // let programName    = args[0]
    let positionalArgs = args.dropFirst().filter { !$0.starts(with: "-") }
    // let optionalArgs   = args.dropFirst().filter { $0.starts(with: "-") }

    if positionalArgs.isEmpty {
        throw CommandError.missingInput
    }

    let source = try String(contentsOf: URL(fileURLWithPath: positionalArgs[0]))
    let module = try AnzenLib.parse(text: source)
    try performSema(on: module)
    print(module.debugDescription)
}

do {
    try main()
} catch let e as SemanticError {
    print(e)
    exit(1)
} catch let e {
    print(e)
    exit(1)
}
exit(0)
