public struct OrderedMap<Key, Value> where Key: Hashable {

  public typealias Element = (key: Key, value: Value)
  public typealias Index = Int

  public init() {
    storage = []
    keyToIndex = [:]
  }

  public init<S>(_ elements: S) where S: Sequence, S.Element == (Key, Value) {
    storage = Array(elements)
    keyToIndex = Dictionary(
      uniqueKeysWithValues: storage.enumerated().map({ ($0.element.key, $0.offset) }))
  }

  public var last: Element? {
    return storage.last
  }

  private var storage: [Element]
  private var keyToIndex: [Key: Index]

}

extension OrderedMap: Collection {

  public var startIndex: Index { return 0 }
  public var endIndex  : Index { return storage.count }

  public func index(after i: Int) -> Int {
    return i + 1
  }

  public subscript(i: Int) -> Element {
    return storage[i]
  }

  public subscript(key: Key) -> Value? {
    get {
      return keyToIndex[key].map { storage[$0].value }
    }
    set {
      if let index = keyToIndex[key] {
        if let value = newValue {
          storage[index] = (key, value)
        } else {
          storage.remove(at: index)
          for i in index ..< storage.count {
            keyToIndex[storage[i].key] = i
          }
        }
      } else if let value = newValue {
        keyToIndex[key] = storage.count
        storage.append((key, value))
      }
    }
  }

}

extension OrderedMap: ExpressibleByDictionaryLiteral {

  public init(dictionaryLiteral elements: (Key, Value)...) {
    self.init(elements)
  }

}
