import AST

struct SubstitutionTable {

  var substitutions: [TypeVar: TypeBase]

  /// The canonical form of this substitution table.
  var canonized: [TypeVar: TypeBase] {
    return substitutions.mapValues { get(for: $0) }
  }

  init(_ substitutions: [TypeVar: TypeBase] = [:]) {
    self.substitutions = substitutions
  }

  func get(for bareType: TypeBase) -> TypeBase {
    guard let variable = bareType as? TypeVar
      else { return bareType }

    var walked = substitutions[variable]
    while let var_ = walked as? TypeVar {
      walked = substitutions[var_]
    }
    return walked ?? bareType
  }

  mutating func set(substitution: TypeBase, for variable: TypeVar) {
    var walked: TypeVar = variable
    while let ty = substitutions[walked] {
      guard let var_ = ty as? TypeVar else {
        assert(ty == substitution, "inconsistent substitution")
        return
      }
      walked = var_
    }

    substitutions[walked] = substitution
  }

  func dump() {
    let keys = substitutions.keys.sorted { a, b in a.info.typeID < b.info.typeID }
    for key in keys {
      print("\(key) => \(substitutions[key]!)")
    }
  }

}

//import AST
//
//private final class MappingRef {
//
//  var value: [TypeVariable: TypeBase]
//
//  init(_ value: [TypeVariable: TypeBase] = [:]) {
//    self.value = value
//  }
//
//}
//
//public struct SubstitutionTable {
//
//  private var mappingsRef: MappingRef
//
//  private var mappings: [TypeVariable: TypeBase] {
//    get { return mappingsRef.value }
//    set {
//      guard isKnownUniquelyReferenced(&mappingsRef) else {
//        mappingsRef = MappingRef(newValue)
//        return
//      }
//      mappingsRef.value = newValue
//    }
//  }
//
//  public init(_ mappings: [TypeVariable: TypeBase] = [:]) {
//    self.mappingsRef = MappingRef(mappings)
//  }
//
//  public func substitution(for type: TypeBase) -> TypeBase {
//    if let var_ = type as? TypeVariable {
//      return mappings[var_].map { substitution(for: $0) } ?? var_
//    }
//    return type
//  }
//
//  public mutating func set(substitution: TypeBase, for var_: TypeVariable) {
//    let walked = self.substitution(for: var_)
//    guard let key = walked as? TypeVariable else {
//      assert(walked == substitution, "inconsistent substitution")
//      return
//    }
//    assert(key != substitution, "occur check failed")
//    mappings[key] = substitution
//  }
//
//  public func reified(in context: ASTContext) -> SubstitutionTable {
//    var visited: [NominalType] = []
//    var reifiedMappings: [TypeVariable: TypeBase] = [:]
//    for (key, value) in mappings {
//      reifiedMappings[key] = reify(type: value, in: context, skipping: &visited)
//    }
//    return SubstitutionTable(reifiedMappings)
//  }
//
//  public func reify(type: TypeBase, in context: ASTContext) -> TypeBase {
//    var visited: [NominalType] = []
//    return reify(type: type, in: context, skipping: &visited)
//  }
//
//  public func reify(type: TypeBase, in context: ASTContext, skipping visited: inout [NominalType])
//    -> TypeBase
//  {
//    let walked = substitution(for: type)
//    if let result = visited.first(where: { $0 == walked }) {
//      return result
//    }
//
//    switch walked {
//    case let t as BoundGenericType:
//      let unbound = reify(type: t.unboundType, in: context, skipping: &visited)
//      if let placeholder = unbound as? PlaceholderType {
//        return reify(type: t.bindings[placeholder]!, in: context, skipping: &visited)
//      }
//
//      let reifiedBindings = Dictionary(
//        uniqueKeysWithValues: t.bindings.map({
//          ($0.key, reify(type: $0.value, in: context, skipping: &visited))
//        }))
//      return BoundGenericType(unboundType: unbound, bindings: reifiedBindings)
//
//    case let t as NominalType:
//      visited.append(t)
//      for symbol in t.members {
//        symbol.type = reify(type: symbol.type!, in: context, skipping: &visited)
//      }
//      return t
//
//    case let t as FunctionType:
//      return context.getFunctionType(
//        from: t.domain.map({
//          Parameter(
//            label: $0.label,
//            type: reify(type: $0.type, in: context, skipping: &visited))
//        }),
//        to: reify(type: t.codomain, in: context, skipping: &visited),
//        placeholders: t.placeholders)
//
//    default:
//      return walked
//    }
//  }
//
//  /// Determines whether this substitution table is equivalent to another one, up to the variables
//  /// they share.
//  ///
//  /// Let a substitution table be a partial function `V -> T` where `V` is the set of type variables
//  /// and `T` the set of types. Two tables `t1`, `t2` are equivalent if for all variable `v` such
//  /// both `t1` and `t2` are defined `t1(v) = t2(v)`. Variables outside of represent intermediate
//  /// results introduced by the solver, and irrelevant after reification.
//  public func isEquivalent(to other: SubstitutionTable) -> Bool {
//    if self.mappingsRef === other.mappingsRef {
//      // Nothing to do if both tables are trivially equal.
//      return true
//    }
//
//    for key in Set(mappings.keys).intersection(other.mappings.keys) {
//      guard mappings[key] == other.mappings[key]
//        else { return false }
//    }
//    return true
//  }
//
//  /// Determines whether this substitution table is more specific than another one, up to the
//  /// variables they share.
//  ///
//  /// Let a substitution table be a partial function `V -> T` where `V` is the set of type variables
//  /// and `T` the set of types. A table `t1` is said more specific than an other table `t2` if the
//  /// set of variables `v` such that `t1(v) < t2(v)` is bigger than the set of variables `w` such
//  /// that `t1(w) > t2(w)`. Variables outside of both domains represent intermediate results
//  /// introduced by the solver, and irrelevant after reification.
//  public func isMoreSpecific(than other: SubstitutionTable) -> Bool {
//    var score = 0
//    for key in Set(mappings.keys).intersection(other.mappings.keys) {
//      if mappings[key]!.isSubtype(of: other.mappings[key]!) {
//        score -= 1
//      } else if mappings[key]!.isSubtype(of: other.mappings[key]!) {
//        score += 1
//      }
//    }
//    return score < 0
//  }
//
//}
//
//extension SubstitutionTable: Hashable {
//
//  public func hash(into hasher: inout Hasher) {
//    for key in mappings.keys {
//      hasher.combine(key)
//    }
//  }
//
//  public static func == (lhs: SubstitutionTable, rhs: SubstitutionTable) -> Bool {
//    return lhs.mappingsRef === rhs.mappingsRef || lhs.mappings == rhs.mappings
//  }
//
//}
//
//extension SubstitutionTable: Sequence {
//
//  public func makeIterator() -> Dictionary<TypeVariable, TypeBase>.Iterator {
//    return mappings.makeIterator()
//  }
//
//}
//
//extension SubstitutionTable: ExpressibleByDictionaryLiteral {
//
//  public init(dictionaryLiteral elements: (TypeVariable, TypeBase)...) {
//    self.init(Dictionary(uniqueKeysWithValues: elements))
//  }
//
//}
//
//extension SubstitutionTable: CustomDebugStringConvertible {
//
//  public var debugDescription: String {
//    var result = ""
//    for (v, t) in self.mappings {
//      result += "\(v) => \(t)\n"
//    }
//    return result
//  }
//
//}
