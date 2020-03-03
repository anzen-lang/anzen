/// A lookup table that keeps track of a nominal type's members for fast retrieval.
public struct MemberLookupTable {

  /// The internal lookup table cache.
  private var lookupTable: [String: [NamedDecl]] = [:]

  /// The compiler context's generation with which this lookup table is synchronized.
  public var generation: Int

  /// Whether all extensions

  public init(generation: Int) {
    self.generation = generation
  }

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
    // Insert members in the context of the declaration extension's body.
    if let body = typeExtDecl.body as? BraceStmt {
      for member in body.decls where member is NamedDecl {
        insert(member: member as! NamedDecl)
      }
    }
  }

  /// Retrieves the declarations matching the given name.
  public subscript(name: String) -> [NamedDecl]? {
    return lookupTable[name]
  }

}
