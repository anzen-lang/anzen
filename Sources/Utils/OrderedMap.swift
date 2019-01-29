public struct OrderedMap<Key, Value> where Key: Hashable {

  public init() {
    self.storage = [:]
    self.order = []
  }

  public init<S>(_ elements: S) where S: Sequence, S.Element == (Key, Value) {
    self.storage = [:]
    self.order = []
    for (key, value) in elements {
      storage[key] = value
      order.append(key)
    }
  }

  private var storage: [Key: Value]
  private var order: [Key]

  public var keys: [Key] {
    return order
  }

  public var values: [Value] {
    return order.map { storage[$0]! }
  }

  public func index(of key: Key) -> Index? {
    return order.firstIndex(of: key)
  }

  public mutating func insert(_ value: Value, forKey key: Key, at index: Index) {
    // Make sure we don't set a duplicate key.
    precondition(storage[key] == nil, "Key '\(key)' already exists")
    storage[key] = value
    order.insert(key, at: index)
  }

  public subscript(key: Key) -> Value? {
    get {
      return storage[key]
    }
    set {
      if let value = newValue {
        if storage[key] == nil {
          order.append(key)
        }
        storage[key] = value
      } else {
        order.removeAll { $0 == key }
        storage[key] = nil
      }
    }
  }

}

extension OrderedMap: MutableCollection {

  public typealias Index = Int
  public typealias Element = (key: Key, value: Value)

  public var startIndex: Index { return 0 }
  public var endIndex: Index { return order.count }

  public func index(after i: Index) -> Index {
    return i + 1
  }

  public subscript(index: Index) -> Element {
    get {
      return (key: order[index], value: storage[order[index]]!)
    } set {
      if let i = self.index(of: newValue.key) {
        // Make sure we don't set a duplicate key at a different index.
        precondition(i == index, "Key '\(newValue.key)' already exists at index \(i)")
      }
      order[index] = newValue.key
      storage[newValue.key] = newValue.value
    }
  }

}

extension OrderedMap: ExpressibleByDictionaryLiteral {

  public init(dictionaryLiteral elements: (Key, Value)...) {
    self.init(elements)
  }

}
