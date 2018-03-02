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

    public var last: T {
        get {
            return self.storage.last!
        }

        set {
            self.storage[self.storage.count - 1] = newValue
        }
    }

    public var isEmpty: Bool {
        return self.storage.isEmpty
    }

    // MARK: Internals

    var storage: [T]

}

extension Stack: ExpressibleByArrayLiteral {

    public init(arrayLiteral elements: T...) {
        self.init(elements)
    }

}
