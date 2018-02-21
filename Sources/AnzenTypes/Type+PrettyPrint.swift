extension TypeQualifier: CustomStringConvertible {

    public var description: String {
        switch self {
        case .cst: return "@cst"
        case .mut: return "@mut"
        }
    }

}

extension QualifiedType: CustomStringConvertible {

    public var description: String {
        return !self.qualifiers.isEmpty
            ? self.qualifiers.map({ $0.description }).joined(separator: " ") + " \(self.type)"
            : "\(self.type)"
    }

}

extension TypeAlias: CustomStringConvertible {

    public var description: String {
        return "~\(self.name)"
    }

}

extension TypeVariable: CustomStringConvertible {

    public var description: String {
        return "$\(self.id)"
    }

}

extension FunctionType: CustomStringConvertible {

    public var description: String {
        let params = self.domain
            .map   ({ ($0.label ?? "_") + ": \($0.type)" })
            .joined(separator: ",")
        return "(\(params)) -> \(self.codomain)"
    }

}

extension StructType: CustomStringConvertible {

    public var description: String {
        return "struct \(self.name) {}"
    }

}
