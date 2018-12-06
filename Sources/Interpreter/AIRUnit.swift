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

  public func getFunction(name: String, type: AIRFunctionType) -> AIRFunction {
    if let fn = functions[name] {
      assert(fn.type == type, "AIR function conflicts with previous declaration")
      return fn
    }

    let fn = AIRFunction(name: name, type: type)
    functions[name] = fn
    return fn
  }

  public func getStructType(name: String) -> AIRStructType {
    if let ty = structTypes[name] {
      return ty
    }

    let ty = AIRStructType(name: name, elements: [])
    structTypes[name] = ty
    return ty
  }

  /// The struct types of the unit.
  public private(set) var structTypes: [String: AIRStructType] = [:]

  public func getAIRType(of type: TypeBase) -> AIRType {
    switch type {
    case is AnythingType:
      return .anything

    case is NothingType:
      return .nothing

    case let ty as FunctionType:
      return getAIRFunctionType(of: ty)

    case let ty as StructType where ty.isBuiltin:
      return .builtin(named: ty.name)!

    case let ty as StructType:
      let airTy = getStructType(name: ty.name)
      if airTy.elements.isEmpty {
        airTy.elements = ty.members.compactMap { mem in
          mem.type is FunctionType
            ? nil
            : getAIRType(of: mem.type!)
        }
      }
      return airTy

    default:
      fatalError("type '\(type)' has no AIR representation")
    }
  }

  public func getAIRFunctionType(of type: FunctionType) -> AIRFunctionType {
    return AIRFunctionType(
      domain: type.domain.map({ getAIRType(of: $0.type) }),
      codomain: getAIRType(of: type.codomain))
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
