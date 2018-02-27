import Parsey

public protocol SemanticError: Error {

    var file    : String?      { get }
    var location: SourceRange? { get }

}

public struct DuplicateDeclarationError: SemanticError, CustomStringConvertible {

    public init(name: String, file: String? = nil, location: SourceRange? = nil) {
        self.name     = name
        self.file     = file
        self.location = location
    }

    public let name    : String
    public let file    : String?
    public let location: SourceRange?

    public var description: String {
        let file     = self.file ?? "?"
        let location = self.location != nil
            ? "\(file):\(self.location!.lowerBound)"
            : "\(file):?:?"
        return "\(location): duplicate declaration: \(self.name)"
    }

}

public struct UndefinedSymbolError: SemanticError, CustomStringConvertible {

    public init(name: String, file: String? = nil, location: SourceRange? = nil) {
        self.name     = name
        self.file     = file
        self.location = location
    }

    public let name    : String
    public let file    : String?
    public let location: SourceRange?

    public var description: String {
        let file     = self.file ?? "?"
        let location = self.location != nil
            ? "\(file):\(self.location!.lowerBound)"
            : "\(file):?:?"
        return "\(location): undefined symbol: \(self.name)"
    }

}

public struct InferenceError: SemanticError, CustomStringConvertible {

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
            ? "\(file):\(self.location!.lowerBound)"
            : "\(file):?:?"
        return self.reason != nil
            ? "\(location): inference error: \(self.reason!)"
            : "\(location): inference error"
    }

}
