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
