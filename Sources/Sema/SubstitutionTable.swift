import AST

private final class MappingRef {

  init(_ value: [TypeVariable: TypeBase] = [:]) {
    self.value = value
  }

  var value: [TypeVariable: TypeBase]

}

public struct SubstitutionTable {

  public init(_ mappings: [TypeVariable: TypeBase] = [:]) {
    self.mappingsRef = MappingRef(mappings)
  }

  private var mappingsRef: MappingRef
  private var mappings: [TypeVariable: TypeBase] {
    get { return mappingsRef.value }
    set {
      guard isKnownUniquelyReferenced(&mappingsRef) else {
        mappingsRef = MappingRef(newValue)
        return
      }
      mappingsRef.value = newValue
    }
  }

  public func substitution(for type: TypeBase) -> TypeBase {
    switch type {
    case let t as TypeVariable:
      return mappings[t].map {
        substitution(for: $0)
      } ?? t

    case let t as ClosedGenericType:
      let unbound = substitution(for: t.unboundType)
      if let placeholder = unbound as? PlaceholderType {
        return substitution(for: t.bindings[placeholder]!)
      }
      return ClosedGenericType(unboundType: unbound, bindings: t.bindings)

    default:
      return type
    }
  }

  public mutating func set(substitution: TypeBase, for var_: TypeVariable) {
    mappings[var_] = substitution
  }

  public func reified(in context: ASTContext) -> SubstitutionTable {
    var visited: [NominalType] = []
    var reifiedMappings: [TypeVariable: TypeBase] = [:]
    for (key, value) in mappings {
      reifiedMappings[key] = reify(type: value, in: context, skipping: &visited)
    }
    return SubstitutionTable(reifiedMappings)
  }

  public func reify(type: TypeBase, in context: ASTContext) -> TypeBase {
    var visited: [NominalType] = []
    return reify(type: type, in: context, skipping: &visited)
  }

  public func reify(type: TypeBase, in context: ASTContext, skipping visited: inout [NominalType])
    -> TypeBase
  {
    let walked = substitution(for: type)
    if let result = visited.first(where: { $0 == walked }) {
      return result
    }

    switch walked {
    case let t as ClosedGenericType:
      let unbound = reify(type: t.unboundType, in: context, skipping: &visited)
      if let placeholder = unbound as? PlaceholderType {
        return reify(type: t.bindings[placeholder]!, in: context, skipping: &visited)
      }

      let reifiedBindings = Dictionary(
        uniqueKeysWithValues: t.bindings.map({
          ($0.key, reify(type: $0.value, in: context, skipping: &visited))
        }))
      return ClosedGenericType(unboundType: unbound, bindings: reifiedBindings)

    case let t as NominalType:
      // Note that reifying a nominal type actually mutates said type.
      visited.append(t)
      for (name, types) in t.members {
        t.members[name] = types.map({ reify(type: $0, in: context, skipping: &visited) })
      }
      return t

    case let t as FunctionType:
      return context.getFunctionType(
        from: t.domain.map({
          Parameter(
            label: $0.label,
            type: reify(type: $0.type, in: context, skipping: &visited))
        }),
        to: reify(type: t.codomain, in: context, skipping: &visited),
        placeholders: t.placeholders)

    default:
      return walked
    }
  }

  public func isMoreSpecific(than other: SubstitutionTable) -> Bool {
    var score = 0
    for key in Set(mappings.keys).intersection(other.mappings.keys) {
      if mappings[key]!.isSubtype(of: other.mappings[key]!) {
        score -= 1
      } else if mappings[key]!.isSubtype(of: other.mappings[key]!) {
        score += 1
      }
    }
    return score < 0
  }

}

extension SubstitutionTable: Hashable {

  public var hashValue: Int {
    return mappings.keys.reduce(17) { h, key in 31 &* h &+ key.hashValue }
  }

  public static func == (lhs: SubstitutionTable, rhs: SubstitutionTable) -> Bool {
    return lhs.mappingsRef === rhs.mappingsRef || lhs.mappings == rhs.mappings
  }

}

extension SubstitutionTable: Sequence {

  public func makeIterator() -> Dictionary<TypeVariable, TypeBase>.Iterator {
    return mappings.makeIterator()
  }

}

extension SubstitutionTable: ExpressibleByDictionaryLiteral {

  public init(dictionaryLiteral elements: (TypeVariable, TypeBase)...) {
    self.init(Dictionary(uniqueKeysWithValues: elements))
  }

}
