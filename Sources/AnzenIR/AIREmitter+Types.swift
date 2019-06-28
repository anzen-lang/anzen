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
    case let ty as BoundGenericType where ty.unboundType is StructType:
      return getBoundGenericType(of: ty)
    default:
      fatalError("type '\(anzenType)' has no AIR representation")
    }
  }

  public func getFunctionType(of anzenType: FunctionType) -> AIRFunctionType {
    return builder.unit.getFunctionType(
      from: anzenType.domain.map({ getType(of: $0.type) }),
      to: getType(of: anzenType.codomain))
  }

  public func getFunctionType(from domain: [AIRType], to codomain: AIRType) -> AIRFunctionType {
    return builder.unit.getFunctionType(from: domain, to: codomain)
  }

  public func getStructType(of anzenType: StructType) -> AIRStructType {
    let mangledName = mangle(symbol: anzenType.decl.symbol!, withType: anzenType)
    if let ty = builder.unit.structTypes[mangledName] {
      return ty
    }

    let ty = builder.unit.getStructType(name: mangledName)
    ty.members = OrderedMap(anzenType.members.compactMap { sym in
      sym.isOverloadable
        ? nil
        : (sym.name, getType(of: sym.type!))
    })
    return ty
  }

  public func getBoundGenericType(of anzenType: BoundGenericType) -> AIRType {
    guard let structType = anzenType.unboundType as? StructType
      else { fatalError("unexpected unbound type") }
    let mangledName = mangle(symbol: structType.decl.symbol!, withType: anzenType)
    if let ty = builder.unit.structTypes[mangledName] {
      return ty
    }

    let ty = builder.unit.getStructType(name: mangledName)
    bindings = anzenType.bindings  // FIXME: This is nothing but a dirty hack
    for symbol in structType.members {
      if !symbol.isOverloadable {
        ty.members[symbol.name] = getType(of: symbol.type!)
      }
    }
    bindings = [:]

    return ty
  }

//  public func getStructType(name: String) -> AIRStructType {
//    return builder.unit.getStructType(name: name)
//  }

}
