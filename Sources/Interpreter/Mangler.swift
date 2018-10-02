import AST

public func mangle(symbol: Symbol) -> String {
  var scopes = [symbol.scope]
  while let parent = scopes.last!.parent {
    scopes.append(parent)
  }

  if scopes.count == 1 && scopes[0].name == "anzen://builtin" {
    return symbol.name
  }

  var result = "_"
  for scope in scopes.reversed() {
    if let name = scope.name {
      result += "\(name.count)\(name)"
    } else {
      result += "_"
    }
  }

  return result + "\(symbol.name.count)\(symbol.name)" + mangle(type: symbol.type!)
}

public func mangle(type: TypeBase) -> String {
  switch type {
  case AnythingType.get:
    return "a"

  case NothingType.get:
    return "n"

  case let nominal as NominalType:
    // FIXME: Use the type's fully qualified name.
    return "N\(nominal.name.count)\(nominal.name)"

  case let function as FunctionType:
    let domain = function.domain.map { (param) -> String in
      let label = param.label.map { "\($0.count)\($0)" } ?? "_"
      return "\(label)\(mangle(type: param.type))"
    }
    let codomain = mangle(type: function.codomain)
    return "F\(domain.joined())2\(codomain)"

  default:
    return ""
  }
}

extension String {

  func replacing(_ character: Character, with replacement: String) -> String {
    var offset = 0
    var result = self

    while offset < result.count {
      let i = index(startIndex, offsetBy: offset)
      if result[i] == character {
        result.remove(at: i)
        result.insert(contentsOf: replacement, at: i)
        offset += replacement.count
      } else {
        offset += 1
      }
    }
    return result
  }

}
