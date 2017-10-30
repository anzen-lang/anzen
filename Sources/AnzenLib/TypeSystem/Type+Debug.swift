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

extension FunctionType: CustomStringConvertible {

    public var description: String {
        let domainDescription = self.domain.map({ param in (param.label ?? "_") + ": \(param.type)" })
            .joined(separator: ", ")
        let codomainDescription = self.codomain != nil
            ? String(describing: self.codomain!)
            : "Nothing"
        return "(\(domainDescription)) -> \(codomainDescription)"
    }

}


extension StructType: CustomStringConvertible {

    public var description: String {
        return self.name
    }

}
