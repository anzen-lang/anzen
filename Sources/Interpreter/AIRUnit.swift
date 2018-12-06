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

  public var description: String {
    return functions.values.map(prettyPrint).sorted().joined(separator: "\n")
  }

  // MARK: Functions

  /// Create or get the existing function with the given name and type.
  public func getFunction(name: String, type: AIRFunctionType) -> AIRFunction {
    if let fn = functions[name] {
      assert(fn.type == type, "AIR function conflicts with previous declaration")
      return fn
    }

    let fn = AIRFunction(name: name, type: type)
    functions[name] = fn
    return fn
  }

  /// The functions of the unit.
  public private(set) var functions: [String: AIRFunction] = [:]

  // MARK: Types

  public func getType(of anzenType: TypeBase) -> AIRType {
    switch anzenType {
    case is AnythingType:
      return .anything

    case is NothingType:
      return .nothing

    case let ty as FunctionType:
      return getFunctionType(of: ty)

    case let ty as StructType where ty.isBuiltin:
      return .builtin(named: ty.name)!

    case let ty as StructType:
      let airTy = getStructType(name: ty.name)
      if airTy.elements.isEmpty {
        airTy.elements = ty.members.compactMap { mem in
          mem.type is FunctionType
            ? nil
            : getType(of: mem.type!)
        }
      }
      return airTy

    case let ty as Metatype:
      return getType(of: ty.type).metatype

    default:
      fatalError("type '\(anzenType)' has no AIR representation")
    }
  }

  public func getStructType(name: String) -> AIRStructType {
    if let ty = structTypes[name] {
      return ty
    }

    let ty = AIRStructType(name: name, elements: [])
    structTypes[name] = ty
    return ty
  }

  public func getFunctionType(of anzenType: FunctionType) -> AIRFunctionType {
    return getFunctionType(
      from: anzenType.domain.map({ getType(of: $0.type) }),
      to: getType(of: anzenType.codomain))
  }

  public func getFunctionType(from domain: [AIRType], to codomain: AIRType) -> AIRFunctionType {
    if let existing = functionTypes.first(where: {
      ($0.domain == domain) && ($0.codomain == codomain)
    }) {
      return existing
    } else {
      let ty = AIRFunctionType(domain: domain, codomain: codomain)
      functionTypes.append(ty)
      return ty
    }
  }

  /// The struct types of the unit.
  public private(set) var structTypes: [String: AIRStructType] = [:]
  /// The function types of the unit.
  public private(set) var functionTypes: [AIRFunctionType] = []

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
