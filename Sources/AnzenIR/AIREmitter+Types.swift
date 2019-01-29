import AST
import Utils

extension AIREmitter {

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
      return getStructType(of: ty)
    case let ty as Metatype:
      return getType(of: ty.type).metatype
    case let ty as PlaceholderType:
      return getType(of: bindings[ty]!)
    default:
      fatalError("type '\(anzenType)' has no AIR representation")
    }
  }

  public func getStructType(of anzenType: StructType) -> AIRStructType {
    if let ty = builder.unit.structTypes[anzenType.name] {
      return ty
    }

    let ty = builder.unit.getStructType(name: anzenType.name)
    ty.members = OrderedMap(anzenType.members.compactMap { sym in
      sym.isOverloadable
        ? nil
        : (sym.name, getType(of: sym.type!))
    })
    return ty
  }

  public func getStructType(name: String) -> AIRStructType {
    return builder.unit.getStructType(name: name)
  }

  public func getFunctionType(of anzenType: FunctionType) -> AIRFunctionType {
    return builder.unit.getFunctionType(
      from: anzenType.domain.map({ getType(of: $0.type) }),
      to: getType(of: anzenType.codomain))
  }

  public func getFunctionType(from domain: [AIRType], to codomain: AIRType) -> AIRFunctionType {
    return builder.unit.getFunctionType(from: domain, to: codomain)
  }

}
