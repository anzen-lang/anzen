public class Reference<T> {

    public init(to wrapped: T) {
        self.wrapped = wrapped
    }

    public var wrapped: T

}
