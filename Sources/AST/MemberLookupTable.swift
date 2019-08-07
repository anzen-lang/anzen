/// A lookup table that keeps track of a nominal type's members for fast retrieval.
public struct MemberLookupTable {

  /// The internal lookup table cache.
  private var lookupTable: [String: [NamedDecl]] = [:]

  public init() {}

  /// Inserts the given member to the lookup table.
  public mutating func insert(member: NamedDecl) {
    if let decls = lookupTable[member.name] {
      // Check if the member has already been inserted.
      guard !decls.contains(where: { $0 === member })
        else { return }
      lookupTable[member.name]!.append(member)
    } else {
      lookupTable[member.name] = [member]
    }
  }

  /// Merges the members of an extension with this lookup table.
  public mutating func merge(extension typeExtDecl: TypeExtDecl) {
    for member in typeExtDecl.namedDecls {
      insert(member: member)
    }
  }

  /// Retrieves the declarations matching the given name.
  subscript(name: String) -> [NamedDecl]? {
    return lookupTable[name]
  }

}
