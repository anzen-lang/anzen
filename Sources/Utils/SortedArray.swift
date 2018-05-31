public struct SortedArray<Element> {

  public typealias Comparator = (Element, Element) -> Bool

  public init(comparator: @escaping Comparator) {
    self.comparator = comparator
    self.elements = []
  }

  public init<S>(_ elements: S, comparator: @escaping Comparator)
    where S: Sequence, S.Element == Element
  {
    self.comparator = comparator
    self.elements = Array(elements.sorted(by: comparator))
  }

  public mutating func insert(_ newElement: Element) {
    if let index = elements.index(where: { comparator($0, newElement) }) {
      elements.insert(newElement, at: index)
    } else {
      elements.append(newElement)
    }
  }

  @discardableResult
  public mutating func remove(at position: Index) -> Element {
    return elements.remove(at: position)
  }

  public mutating func popLast() -> Element? {
    return elements.popLast()
  }

  public let comparator: Comparator
  fileprivate var elements: [Element]

}

extension SortedArray: Collection {

  public typealias Index = Array<Element>.Index

  public var startIndex: Index { return elements.startIndex }
  public var endIndex: Index { return elements.endIndex }

  public func index(after i: Index) -> Index {
    return elements.index(after: i)
  }

  public subscript(position: Index) -> Element {
    return elements[position]
  }

}

extension SortedArray where Element: Comparable {

  public init() {
    self.init(comparator: { $0 < $1 })
  }

  public init<S>(_ elements: S) where S: Sequence, S.Element == Element {
    self.init(elements, comparator: { $0 < $1 })
  }

}
