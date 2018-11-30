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

  /// Evaluates whether or not all elements in the sequence satisfy a given predicate.
  public func all(satisfy predicate: (Element) throws -> Bool) rethrows -> Bool {
    for element in self {
      guard try predicate(element) else { return false }
    }
    return true
  }

}

extension Array {

  /// Adds a new element at the beginning of the array.
  public mutating func prepend(_ newElement: Element) {
    insert(newElement, at: 0)
  }

}

public struct Zip3Sequence<S1, S2, S3>: IteratorProtocol, Sequence
  where S1: Sequence, S2: Sequence, S3: Sequence
{

  // swiftlint:disable:next large_tuple
  public mutating func next() -> (S1.Element, S2.Element, S3.Element)? {
    guard let e1 = i1.next(), let e2 = i2.next(), let e3 = i3.next() else { return nil }
    return (e1, e2, e3)
  }

  private var i1: S1.Iterator
  private var i2: S2.Iterator
  private var i3: S3.Iterator

  init(_ i1: S1.Iterator, _ i2: S2.Iterator, _ i3: S3.Iterator) {
    self.i1 = i1
    self.i2 = i2
    self.i3 = i3
  }

}

public func zip<S1, S2, S3>(_ s1: S1, _ s2: S2, _ s3: S3) -> Zip3Sequence<S1, S2, S3>
  where S1: Sequence, S2: Sequence, S3: Sequence
{
  return Zip3Sequence(s1.makeIterator(), s2.makeIterator(), s3.makeIterator())
}
