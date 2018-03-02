/// A wrapper around `Array` that lets us manipulate the top element as a `var`.
public struct Stack<T> {

    public init(_ elements: [T] = []) {
        self.storage = elements
    }

    public mutating func push(_ element: T) {
        self.storage.append(element)
    }

    @discardableResult
    public mutating func pop() -> T? {
        return self.storage.popLast()
    }

    public var top: T? {
        get { return self.storage.last }
        set {
            if newValue != nil {
                self.storage[self.storage.count - 1] = newValue!
            } else {
                self.storage.removeLast()
            }
        }
    }

    public var isEmpty: Bool {
        return self.storage.isEmpty
    }

    public var count: Int {
        return self.storage.count
    }

    // MARK: Internals

    private var storage: [T]

}

extension Stack: Collection {

    public typealias Index   = Array<T>.Index
    public typealias Element = Array<T>.Element

    public var startIndex: Index {
        return self.storage.startIndex
    }

    public var endIndex: Index {
        return self.storage.endIndex
    }

    public func index(after i: Index) -> Index {
        return self.storage.index(after: i)
    }

    public subscript(index: Index) -> Element {
        return self.storage[index]
    }

}

extension Stack: ExpressibleByArrayLiteral {

    public init(arrayLiteral elements: T...) {
        self.init(elements)
    }

}
