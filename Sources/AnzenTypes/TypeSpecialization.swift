// swiftlint:disable cyclomatic_complexity

public class TypeSpecialization: SemanticType {

    public init(
        specializing type   : GenericType,
        with specializations: [TypePlaceholder: SemanticType])
    {
        self.genericType     = type
        self.specializations = specializations
    }

    public func equals(to other: SemanticType, table: EqualityTableRef) -> Bool {
        if self === other {
            return true
        }

        let pair = TypePair(self, other)
        if let result = table.wrapped[pair] {
            return result
        }

        guard let rhs = other as? TypeSpecialization,
            self.genericType.equals(to: rhs.genericType, table: table),
            _equals(args: self.specializations, to: rhs.specializations, table: table)
        else {
            table.wrapped[pair] = false
            return false
        }

        table.wrapped[pair] = true
        return true
    }

    public let genericType    : GenericType
    public let specializations: [TypePlaceholder: SemanticType]

}

extension SemanticType {

    /// Specializes the type with the given mapping.
    public func specialized(with mapping: TypeMap = TypeMap()) -> SemanticType {
        // Check if we already chose a specialization for `type`.
        if let specialization = mapping[self] {
            return specialization
        }

        switch self {
        case _ as TypePlaceholder:
            return self

        case let f as FunctionType:
            let chosenArgs = mapping.keys.flatMap { $0 as? TypePlaceholder }
            return FunctionType(
                placeholders: f.placeholders.subtracting(chosenArgs),
                from: f.domain.map({ ($0.label, $0.type.specialized(with: mapping)) }),
                to: f.codomain.specialized(with: mapping))

        case let s as StructType:
            let chosenArgs = mapping.keys.flatMap { $0 as? TypePlaceholder }
            let specialized = StructType(
                name: s.name,
                placeholders: s.placeholders.subtracting(chosenArgs))
            mapping[s] = specialized

            for (key, value) in s.properties {
                specialized.properties[key] = value.specialized(with: mapping)
            }
            for (key, values) in s.methods {
                specialized.methods[key] = values.map {
                    $0.specialized(with: mapping)
                }
            }

            return specialized

        case let other:
            return other
        }
    }

    /// Attempts to specialize the type so that it matches the given `pattern`.
    public func specialized(with pattern: SemanticType, mapping: TypeMap = TypeMap())
        -> SemanticType?
    {
        // Nothing to specialize if the types are already equivalent.
        guard !self.equals(to: pattern) else { return self }

        // Check if we already chose a specialization for `type`.
        if let specialization = mapping[self] {
            return specialization
        }

        switch (self, pattern) {
        case (let p as TypePlaceholder, _):
            mapping[p] = pattern
            return pattern

        case (_, _ as TypePlaceholder):
            return pattern.specialized(with: self, mapping: mapping)

        case (let fnl as FunctionType, let fnr as FunctionType):
            // Make sure the domain of both functions agree.
            guard fnl.domain.count == fnr.domain.count else { return nil }

            var domain: [ParameterDescription] = []
            for (dl, dr) in zip(fnl.domain, fnr.domain) {
                // Make sure the labels are identical.
                guard dl.label == dr.label else { return nil }

                // Specialize the parameter.
                guard let specialized = dl.type.specialized(with: dr.type, mapping: mapping)
                    else { return nil }
                domain.append((label: dl.label, type: specialized))
            }

            // Specialize the codomain.
            guard let codomain = fnl.codomain.specialized(with: fnr.codomain, mapping: mapping)
                else { return nil }

            // Return the specialized function.
            // FIXME: What about the placeholders?
            return FunctionType(from: domain, to: codomain)

        case (let sl as StructType, let sr as StructType):
            guard sl.name == sr.name else { return nil }

            // TODO: Specialize struct types.
            fatalError("TODO")

        case (_ as TypeVariable, _):
            return self

        case (_, _ as TypeVariable):
            return self

        default:
            return nil
        }
    }

}

extension QualifiedType {

    public func specialized(with pattern: QualifiedType, mapping: TypeMap) -> QualifiedType? {
        guard self.qualifiers.isEmpty
            || pattern.qualifiers.isEmpty
            || (self.qualifiers == pattern.qualifiers)
            else { return nil }

        return self.type.specialized(with: pattern.type, mapping: mapping)?
            .qualified(by: self.qualifiers.union(pattern.qualifiers))
    }

    public func specialized(with mapping: TypeMap) -> QualifiedType {
        return self.type.specialized(with: mapping).qualified(by: self.qualifiers)
    }

}

public class TypeMap {

    public init() {
        self.content = []
    }

    public init<S>(_ elements: S) where S: Sequence, S.Element == (SemanticType, SemanticType) {
        self.content = Array(elements)
    }

    public subscript(object: SemanticType) -> SemanticType? {
        get {
            return self.content.first(where: { $0.key === object })?.value
        }

        set {
            if let index = self.content.index(where: { $0.key === object }) {
                if let value = newValue {
                    self.content[index] = (key: object, value: value)
                } else {
                    self.content.remove(at: index)
                }
            } else if let value = newValue {
                self.content.append((key: object, value: value))
            }
        }
    }

    public var keys: [SemanticType] {
        return self.content.map({ $0.key })
    }

    public var values: [SemanticType] {
        return self.content.map({ $0.value })
    }

    private var content: [(key: SemanticType, value: SemanticType)]

}

// MARK: Internal

private func _equals(
    args  lhs: [TypePlaceholder: SemanticType],
    to    rhs: [TypePlaceholder: SemanticType],
    table    : EqualityTableRef) -> Bool
{
    guard lhs.count == rhs.count else { return false }
    for (key, lvalue) in lhs {
        guard let rvalue = rhs[key]                   else { return false }
        guard lvalue.equals(to: rvalue, table: table) else { return false }
    }
    return true
}
