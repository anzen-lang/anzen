import AST
import Utils

public func mangle(symbol: Symbol, withType type: TypeBase? = nil) -> String {
  let symTy = type ?? symbol.type!
  return "\(symbol.scope.mangled)_\(symbol.name)_\(mangle(type: symTy))"
}

public func mangle(type: TypeBase) -> String {
  switch type {
  case AnythingType.get:
    return "a"

  case NothingType.get:
    return "n"

  case let nominalTy as NominalType:
    if nominalTy.isBuiltin {
      switch nominalTy.name {
      case "Bool"   : return "b"
      case "Int"    : return "i"
      case "Float"  : return "f"
      case "String" : return "s"
      default: break
      }
    }
    return "N" + nominalTy.decl.scope!.mangled + nominalTy.decl.name

  case let fnTy as AST.FunctionType:
    assert(fnTy.placeholders.isEmpty)
    let domain = fnTy.domain.map { (param) -> String in
      return "\(param.label ?? "_")\(mangle(type: param.type))"
    }
    let codomain = mangle(type: fnTy.codomain)
    return "F\(domain.joined())2\(codomain)"

  case let ty as BoundGenericType:
    var suffix = ""
    for placeholder in ty.bindings.keys.sorted(by: { (a, b) in a.name < b.name }) {
      suffix += placeholder.name + mangle(type: ty.bindings[placeholder]!)
    }
    return mangle(type: ty.unboundType) + suffix

  case let ty as PlaceholderType:
    return ty.name

  default:
    unreachable()
  }
}

extension Scope {

  fileprivate var mangled: String {
    var result = ""
    var scope: Scope? = self
    while scope != nil {
      result = (scope?.name ?? "_") + result
      scope = scope?.parent
    }
    return result
  }

}

extension FunDecl {

  func getAIRName(specializedWithType type: TypeBase) -> String {
    if let directive = directives.first(where: { $0.name == "air_name" }) {
      assert(directive.arguments.count == 1, "'air_name' directive expects 1 argument")
      return directive.arguments[0]
    } else {
      return mangle(symbol: symbol!, withType: type)
    }
  }

}
