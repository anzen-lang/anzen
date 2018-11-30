import AST
import Utils

public class AIRUnit: CustomStringConvertible {

  public init(name: String, isMain: Bool = false) {
    self.name = name
    self.isMain = isMain
  }

  /// The name of the unit.
  public let name: String
  /// Whether or not the unit is the program's entry.
  public let isMain: Bool

  /// The functions of the unit.
  public private(set) var functions: [String: AIRFunction] = [:]

  public func getFunction(name: String, type: FunctionType) -> AIRFunction {
    if let fn = functions[name] {
      assert(fn.type == type, "AIR function conflicts with previous declaration")
      return fn
    }

    let fn = AIRFunction(name: name, type: type)
    functions[name] = fn
    return fn
  }

  public var description: String {
    return functions.values.map(prettyPrint).sorted().joined(separator: "\n")
  }

}

private func prettyPrint(function: AIRFunction) -> String {
  var result = "fun $\(function.name) : \(function.type)"
  if function.blocks.isEmpty {
    return result + "\n"
  }

  result += " {\n"
  for (label, block) in function.blocks {
    result += "\(label):\n"
    for line in block.description.split(separator: "\n") {
      result += "  \(line)\n"
    }
  }
  result += "}\n"
  return result
}
