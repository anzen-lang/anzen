import Parsey

public enum CompilerError: Error {

    case duplicateDeclaration(name: String, location: SourceRange?)
    case undefinedSymbol(name: String, location: SourceRange?)
    case inferenceError(file: String, line: Int)

}
