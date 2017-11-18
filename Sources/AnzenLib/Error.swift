import Parsey

public enum CompilerError: Error {

    case duplicateDeclaration(name: String, location: SourceRange?)
    case undefinedSymbol(name: String, location: SourceRange?)
    case inferenceError(file: String, line: Int)

}

public struct InferenceError: Error, CustomStringConvertible {

    public init(reason: String? = nil, file: String? = nil, location: SourceRange? = nil) {
        self.reason   = reason
        self.file     = file
        self.location = location
    }

    public let reason  : String?
    public let file    : String?
    public let location: SourceRange?

    public var description: String {
        let file     = self.file ?? "?"
        let location = self.location != nil
            ? "\(file):\(self.location!.lowerBound.line):\(self.location!.lowerBound.column)"
            : "\(file):?:?"
        return self.reason != nil
            ? "\(location): inference error: \(self.reason!)"
            : "\(location): inference error"
    }

}

public struct IRGenError: Error {

    public init(reason: String? = nil, file: String? = nil, location: SourceRange? = nil) {
        self.reason   = reason
        self.file     = file
        self.location = location
    }

    public let reason  : String?
    public let file    : String?
    public let location: SourceRange?

}
