import AST
import Utils

extension AIREmitter {

  func emitType(of anzenType: TypeBase) -> AIRType {
    switch anzenType {
    case is AnythingType:
      return .anything

    case is NothingType:
      return .nothing

    case let ty as FunctionType:
      return builder.unit.getFunctionType(
        from: ty.domain.map({ emitType(of: $0.type) }),
        to: emitType(of: ty.codomain))

    case let ty as StructType where ty.isBuiltin:
      return .builtin(named: ty.name)!

    case let ty as StructType:
      return emitType(of: ty)

    case let ty as Metatype:
      return emitType(of: ty.type).metatype

    case let ty as PlaceholderType:
      return emitType(of: bindings[ty]!)

    case let ty as BoundGenericType where ty.unboundType is StructType:
      return emitType(of: ty)

    default:
      fatalError("type '\(anzenType)' has no AIR representation")
    }
  }

  func emitType(of anzenType: FunctionType) -> AIRFunctionType {
    return builder.unit.getFunctionType(
      from: anzenType.domain.map({ emitType(of: $0.type) }),
      to: emitType(of: anzenType.codomain))
  }

  func emitType(from domain: [AIRType], to codomain: AIRType) -> AIRFunctionType {
    return builder.unit.getFunctionType(from: domain, to: codomain)
  }

  func emitType(of anzenType: StructType) -> AIRStructType {
    let mangledName = mangle(symbol: anzenType.decl.symbol!, withType: anzenType)
    if let ty = builder.unit.structTypes[mangledName] {
      return ty
    }

    let ty = builder.unit.getStructType(name: mangledName)
    ty.members = OrderedMap(anzenType.members.compactMap { sym in
      sym.isOverloadable
        ? nil
        : (sym.name, emitType(of: sym.type!))
    })
    return ty
  }

  func emitType(of anzenType: BoundGenericType) -> AIRType {
    guard let structType = anzenType.unboundType as? StructType
      else { fatalError("unexpected unbound type") }
    let mangledName = mangle(symbol: structType.decl.symbol!, withType: anzenType)
    if let ty = builder.unit.structTypes[mangledName] {
      return ty
    }

    let previousBindings = bindings
    for (key, value) in anzenType.bindings {
      if let placeholder = value as? PlaceholderType {
        bindings[key] = bindings[placeholder] ?? placeholder
      } else {
        bindings[key] = value
      }
    }
    defer { bindings = previousBindings }

    let ty = builder.unit.getStructType(name: mangledName)
    for symbol in structType.members {
      if !symbol.isOverloadable {
        ty.members[symbol.name] = emitType(of: symbol.type!)
      }
    }

    return ty
  }

}
