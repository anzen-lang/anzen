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

extension TypeSpecialization: CustomStringConvertible {

    public var description: String {
        let placeholders = self.specializations
            .sorted(by: { a, b in a.key.name < b.key.name })
            .map { "\($0.key.name) = \($0.value)" }
            .joined(separator: ", ")
        return "<\(placeholders)>(\(self.genericType))"
    }

}

extension TypeVariable: CustomStringConvertible {

    public var description: String {
        return "$\(self.id)"
    }

}

extension TypePlaceholder: CustomStringConvertible {

    public var description: String {
        return self.name
    }

}

extension FunctionType: CustomStringConvertible {

    public var description: String {
        let placeholders = !self.placeholders.isEmpty
            ? "<" + self.placeholders
                .map   ({ $0.description })
                .sorted()
                .joined(separator: ", ") + ">"
            : ""
        let params = self.domain
            .map   ({ ($0.label ?? "_") + ": \($0.type)" })
            .joined(separator: ",")
        return "\(placeholders)(\(params)) -> \(self.codomain)"
    }

}

extension SelfType: CustomStringConvertible {

    public var description: String {
        return "Self(\(self.type))"
    }

}

extension StructType: CustomStringConvertible {

    public var description: String {
        let placeholders = !self.placeholders.isEmpty
            ? "<" + self.placeholders
                .map   ({ $0.description })
                .sorted()
                .joined(separator: ", ") + ">"
            : ""
        return "\(self.name)\(placeholders)"
    }

}
