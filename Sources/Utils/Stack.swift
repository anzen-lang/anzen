/// A wrapper around `Array` that lets us manipulate the top element as a `var`.
public struct Stack<Element> {

  public init(_ elements: [Element] = []) {
    self.storage = elements
  }

  public mutating func push(_ element: Element) {
    storage.append(element)
  }

  @discardableResult
  public mutating func pop() -> Element? {
    return storage.popLast()
  }

  @discardableResult
  public mutating func pop(if predicate: (Element) throws -> Bool) rethrows -> Element? {
    guard let value = top, try predicate(value) else { return nil }
    return pop()
  }

  @discardableResult
  public mutating func pop(upTo n: Int) -> [Element] {
    let result: [Element] = storage
      .dropFirst(Swift.max(storage.count - n, 0))
      .reversed()
    storage.removeLast(result.count)
    return result
  }

  public var top: Element? {
    get { return storage.last }
    set {
      if newValue != nil {
        storage[storage.count - 1] = newValue!
      } else {
        storage.removeLast()
      }
    }
  }

  public var isEmpty: Bool {
    return storage.isEmpty
  }

  public var count: Int {
    return storage.count
  }

  // MARK: Internals

  private var storage: [Element]

}

extension Stack: Collection {

  public typealias Index = Int

  public var startIndex: Index {
    return storage.count - 1
  }

  public var endIndex: Index {
    return -1
  }

  public func index(after i: Index) -> Index {
    return i - 1
  }

  public subscript(index: Index) -> Element {
    return storage[index]
  }

}

extension Stack: ExpressibleByArrayLiteral {

  public init(arrayLiteral elements: Element...) {
    self.init(elements)
  }

}
