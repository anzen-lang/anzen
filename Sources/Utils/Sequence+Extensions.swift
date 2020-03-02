extension Sequence {

  /// Finds the duplicate in the sequence, using a closure to discriminate between values.
  public func duplicates<T>(groupedBy discriminator: (Element) -> T) -> [Element]
    where T: Hashable
  {
    var present: Set<T> = []
    var result: [Element] = []

    for element in self {
      let key = discriminator(element)
      if present.insert(key).inserted != true {
        result.append(element)
      }
    }
    return result
  }

}

extension Array {

  /// Adds a new element at the beginning of the array.
  public mutating func prepend(_ newElement: Element) {
    insert(newElement, at: 0)
  }

}
