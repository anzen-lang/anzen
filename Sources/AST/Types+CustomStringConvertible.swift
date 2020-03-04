extension TypeQual: CustomStringConvertible {

  public var description: String {
    if args.isEmpty {
      return "\(kind)"
    } else {
      let argsRepr = args.map({ String(describing: $0) }).joined(separator: ", ")
      return "\(kind)(\(argsRepr))"
    }
  }

}

extension TypeQual.Kind: CustomStringConvertible {

  public var description: String {
    switch self {
    case .cst: return "@cst"
    case .mut: return "@mut"
    case .own: return "@own"
    case .brw: return "@brw"
    case .esc: return "@esc"
    }
  }

  public static func < (lhs: TypeQual.Kind, rhs: TypeQual.Kind) -> Bool {
    return lhs.rawValue < rhs.rawValue
  }

}

extension QualType: CustomStringConvertible {

  public var description: String {
    if quals.isEmpty {
      return "@? \(bareType)"
    } else {
      let qualsRepr = quals
        .sorted(by: { a, b in a.kind < b.kind })
        .map(String.init)
        .joined(separator: " ")
      return "\(qualsRepr) \(bareType)"
    }
  }

}

extension TypeKind: CustomStringConvertible {

  public var description: String {
    return "Kind<\(type)>"
  }

}

extension TypeVar: CustomStringConvertible {

  public var description: String {
    return "$\(info.typeID)"
  }

}

extension TypePlaceholder: CustomStringConvertible {

  public var description: String {
    return name
  }

}

extension BoundGenericType: CustomStringConvertible {

  public var description: String {
    if let placeholder = type as? TypePlaceholder {
      if let type = bindings[placeholder] {
        return String(describing: type.bareType)
      } else {
        return "_"
      }
    }

    let arguments = bindings.sorted(by: { a, b in a.key.name < b.key.name })
      .map { key, value in "\(key)=\(value)" }
      .joined(separator: ", ")

    switch type {
    case let nominalTy as NominalType:
      return "\(nominalTy.name)<\(arguments)>"

    case let builtinTy as BuiltinType:
      return "\(builtinTy.name)<\(arguments)>"

    case let funTy as FunType:
      let params = funTy.dom.map(String.init).joined(separator: ", ")
      return "<\(arguments)>(\(params)) -> \(funTy.codom)"

    default:
      return "<\(arguments)>\(type)"
    }
  }

}

extension FunType: CustomStringConvertible {

  public var description: String {
    let params = dom.map(String.init).joined(separator: ", ")
    if placeholders.isEmpty {
      return "(\(params)) -> \(codom)"
    } else {
      let genericParams = self.placeholders.map({ $0.name }).joined(separator: ", ")
      return "<\(genericParams)>(\(params)) -> \(codom)"
    }
  }

}

extension FunType.Param: CustomStringConvertible {

  public var description: String {
    return "\(label ?? "_"): \(type)"
  }

}

extension NominalType: CustomStringConvertible {

  public var description: String {
    if placeholders.isEmpty {
      return name
    } else {
      let params = self.placeholders
        .map(String.init)
        .joined(separator: ", ")
      return "\(name)<\(params)>"
    }
  }

}

extension BuiltinType: CustomStringConvertible {

  public var description: String {
    if placeholders.isEmpty {
      return name
    } else {
      let params = self.placeholders
        .map(String.init)
        .joined(separator: ", ")
      return "\(name)<\(params)>"
    }
  }

}

extension ErrorType: CustomStringConvertible {

  public var description: String {
    return "<error type>"
  }

}
