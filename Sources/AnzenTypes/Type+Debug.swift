extension QualifiedType: CustomStringConvertible {

    public var description: String {
        if self.unqualified is TypeUnion {
            return String(describing: self.unqualified)
        } else {
            return "\(self.qualifiers) \(self.unqualified)"
        }
    }

}

extension TypeQualifier: CustomStringConvertible {

    public var description: String {
        var result = [String]()
        if self.contains(.cst) { result.append("@cst") }
        if self.contains(.mut) { result.append("@mut") }
        if self.contains(.stk) { result.append("@stk") }
        if self.contains(.shd) { result.append("@shd") }
        if self.contains(.val) { result.append("@val") }
        if self.contains(.ref) { result.append("@ref") }
        return result.joined(separator: " ")
    }

}

extension TypeUnion: CustomStringConvertible {

    public var description: String {
        return "{" + self.map({ String(describing: $0) }).joined(separator: ", ") + "}"
    }

}

extension TypeVariable: CustomStringConvertible {

    public var description: String {
        return "$\(self.id)"
    }

}

extension TypeName: CustomStringConvertible {

    public var description: String {
        return "TypeName[\(self.type)]"
    }

}

extension TypePlaceholder: CustomStringConvertible {

    public var description: String {
        return self.name
    }

}

extension FunctionType: CustomStringConvertible {

    public var description: String {
        let placehodersDescription = !self.placeholders.isEmpty
            ? "<" + self.placeholders.sorted().joined(separator: ", ") + ">"
            : ""
        let domainDescription = self.domain
            .map { param in (param.label ?? "_") + ": \(param.type)" }
            .joined(separator: ", ")
        return "\(placehodersDescription)(\(domainDescription)) -> \(self.codomain)"
    }

}


extension StructType: CustomStringConvertible {

    public var description: String {
        return self.name
    }

}
