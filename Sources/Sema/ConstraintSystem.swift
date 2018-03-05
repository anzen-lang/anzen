// swiftlint:disable cyclomatic_complexity

import AnzenAST
import AnzenTypes
import Parsey

public class ConstraintSystem {

    public typealias Solution = [TypeVariable: SemanticType]

    public enum Result {
        case solution(Solution)
        case error   (Error)
    }

    public init<S>(constraints: S, partialSolution: Solution = [:])
        where S: Sequence, S.Element == Constraint
    {
        self.constraints = Array(constraints)
        self.solution    = partialSolution
    }

    public func next() -> Result? {
        // If there's a non-depleted sub-system, first iterate through its solutions.
        while let subSystem = self.subSystems.first {
            if let result = subSystem.next() {
                if case .error(_) = result {
                    self.subSystems.removeFirst()
                }
                return result
            } else {
                self.subSystems.removeFirst()
            }
        }

        guard !self.done else { return nil }

        // Try to solve as many constraints as possible before creating a sub-system.
        while let constraint = self.constraints.popLast() {
            do {
                try self.solveConstraint(constraint)
            } catch {
                return .error(error)
            }
        }

        if let subSystem = self.subSystems.first {
            return subSystem.next()
        }

        let memo = Memo()
        var reified: Solution = [:]
        for (key, value) in self.solution {
            reified[key] = self.deepWalk(value, memo: memo)
        }

        self.done = true
        return .solution(reified)
    }

    // MARK: Internals

    private func solveConstraint(_ constraint: Constraint) throws {
        switch constraint {
        case .equals(type: let x, to: let y, at: let loc):
            try self.solveEquality(between: x, and: y, at: loc)

        case .conforms(type: let x, to: let y, at: let loc):
            // TODO: For the time being, we process conformance constraint the same way we
            // process equality constraints. However, when we'll implement interfaces, we'll
            // have to use a different kind of unification. Moreover, this will probably
            // require some knowledge on the type profiles to have already been inferred.
            try self.solveEquality(between: x, and: y, at: loc)

        case .specializes(type: let x, with: let y, using: let z, at: let loc):
            try self.solveSpecialization(of: x, with: y, using: z, at: loc)

        case .belongs(symbol: let symbol, to: let type, at: let loc):
            // Membership constraints require the profile of the owning type to have already been
            // inferred. When that's the case, it can be solved immediately, unless the targetted
            // member is overloaded, in which case a sub-system will be created with a disjunction
            // of constraints for each of the overloads. If the owning type hasn't been inferred
            // yet, the constraint is deferred.
            try self.solveMembership(of: symbol, in: type, at: loc)

        case .disjunction(let choices):
            // A disjunction of constraints represents possible backtracking points. Whenever we
            // encounter one, we explore all solutions that can be produced for each choice in
            // sub-systems containing that should solve the remaining constraints.
            self.subSystems = choices.map {
                ConstraintSystem(
                    constraints    : self.constraints + [$0],
                    partialSolution: self.solution)
            }

            self.constraints = []
            self.done        = true
        }
    }

    private func solveEquality(
        between x: SemanticType, and y: SemanticType, at loc: SourceRange?) throws
    {
        try self.unify(x, y)
    }

    private func solveSpecialization(
        of    type   : SemanticType,
        with  pattern: SemanticType,
        using args   : [String: SemanticType],
        at   loc     : SourceRange?) throws
    {
        let a = self.walk(type)
        let b = self.walk(pattern)

        // Defer the constraint if the unspecialized type is as yet unknown.
        guard !(a is TypeVariable) else {
            self.constraints.insert(
                .specializes(type: a, with: b, using: args, at: loc), at: 0)
            return
        }

        // Specializing a type alias with a function type isn't necessary inconsistent. It may
        // happen when the former is used as a callee to represent a type initializer. In this
        // case, we must look for the type's initializers and try to specialize each one of them.
        if let alias = a as? TypeAlias, let fun = b as? FunctionType {
            let aliasedType = self.walk(alias.type)
            guard !(aliasedType is TypeVariable) else {
                self.constraints.insert(
                    .specializes(type: alias, with: pattern, using: args, at: loc), at: 0)
                return
            }

            let initializer = Symbol(name: "__new__")
            self.constraints.append(
                .specializes(type: initializer.type, with: fun, using: [:], at: loc))

            if let unspecialized = aliasedType as? GenericType {
                // Make sure no undefined specialization argument was supplied.
                let unspecified = Set(args.keys)
                    .subtracting(unspecialized.placeholders.map({ $0.name }))
                guard unspecified.isEmpty else {
                    throw InferenceError(
                        reason: "Superfluous explicit specializations: \(unspecified)")
                }

                var mapping: [TypePlaceholder: SemanticType] = [:]
                for ph in unspecialized.placeholders {
                    if let specialized = args[ph.name] {
                        mapping[ph] = specialized
                    }
                }

                self.constraints.append(
                    .belongs(
                        symbol: initializer,
                        to: TypeSpecialization(specializing: unspecialized, with: mapping),
                        at: loc))
            } else {
                self.constraints.append(.belongs(symbol: initializer, to: aliasedType, at: loc))
            }

            return
        }

        // If the unspecialized type isn't generic, this boils down to an equality constraint.
        guard let unspecialized = a as? GenericType else {
            try self.solveEquality(between: a, and: b, at: loc)
            return
        }

        // Make sure no undefined specialization argument was supplied.
        let unspecified = Set(args.keys).subtracting(unspecialized.placeholders.map({ $0.name }))
        guard unspecified.isEmpty else {
            throw InferenceError(
                reason: "Superfluous explicit specializations: \(unspecified)")
        }

        // Initialize the specialization memo with the arguments provided explicitly.
        let memo = Memo()
        for ph in unspecialized.placeholders {
            if let specialization = args[ph.name] {
                memo[ph] = specialization
            }
        }

        // Specialize the function.
        guard var specialized = self.specialize(type: unspecialized, with: b, memo: memo) else {
            throw InferenceError(reason: "'\(b)' is not a specialization of '\(a)'")
        }
        specialized = self.replaceGenericReferences(in: specialized, memo: memo)
        try self.solveEquality(between: specialized, and: b, at: loc)
    }

    private func solveMembership(
        of symbol: Symbol, in type: SemanticType, at loc: SourceRange?) throws
    {
        guard let members = self.find(member: symbol.name, in: type) else {
            self.constraints.insert(.belongs(symbol: symbol, to: type, at: loc), at: 0)
            return
        }
        guard !members.isEmpty else {
            let walked = self.walk(type)
            throw InferenceError(reason: "'\(walked)' has no member '\(symbol.name)'")
        }

        self.constraints.append(.or(members.map({
            Constraint.equals(type: symbol.type, to: $0, at: loc)
        })))
        return
    }

    /// Unifies two types.
    ///
    /// Unification is the mechanism we use to bind type variables to their actual type. The main
    /// concept is that given two types (possibly aggregates of multiple subtypes), we try to find
    /// one possible binding for which the types are equivalent. If such binding can't be found,
    /// then the constraints are unsatisfiable, meaning that the program is type-inconsistent.
    private func unify(_ x: SemanticType, _ y: SemanticType, memo: Memo = Memo()) throws {
        let a = self.walk(x)
        let b = self.walk(y)

        // Nothing to unify if the types are already equivalent.
        guard !a.equals(to: b) else { return }

        switch (a, b) {
        case (let v as TypeVariable, _):
            self.solution[v] = b
        case (_, let v as TypeVariable):
            self.solution[v] = a

        case (let fnl as FunctionType, let fnr as FunctionType):
            // Make sure the domain of both functions agree.
            guard fnl.domain.count == fnr.domain.count else {
                throw InferenceError(reason: "'\(fnl)' is not '\(fnr)'")
            }

            // Unify the functions' domains.
            for (dl, dr) in zip(fnl.domain, fnr.domain) {
                // Make sure the labels are identical.
                guard dl.label == dr.label else {
                    throw InferenceError(reason: "'\(fnl)' is not '\(fnr)'")
                }

                try self.unify(dl.type.type, dr.type.type, memo: memo)
            }

            // Unify the functions' codomains.
            try self.unify(fnl.codomain.type, fnr.codomain.type, memo: memo)

        case (let sl as StructType, let sr as StructType):
            guard sl.name == sr.name else {
                throw InferenceError(reason: "'\(sl)' is not '\(sr)'")
            }

        default:
            fatalError("TODO")
        }
    }

    /// Attempts to specialize `type` so that it matches `pattern`.
    private func specialize(
        type: SemanticType, with pattern: SemanticType, memo: Memo = Memo()) -> SemanticType?
    {
        let a = self.walk(type)
        let b = self.walk(pattern)

        // Nothing to specialize if the types are already equivalent.
        guard !a.equals(to: b) else { return a }

        switch (a, b) {
        case (let p as TypePlaceholder, _):
            if let specialization = memo[p] {
                return specialization
            } else {
                memo[p] = b
                return b
            }

        case (_, _ as TypePlaceholder):
            return self.specialize(type: b, with: a, memo: memo)

        case (let fnl as FunctionType, let fnr as FunctionType):
            // Make sure the domain of both functions agree.
            guard fnl.domain.count == fnr.domain.count else { return nil }

            var domain: [ParameterDescription] = []
            for (dl, dr) in zip(fnl.domain, fnr.domain) {
                // Make sure the labels are identical.
                guard dl.label == dr.label else { return nil }

                // Specialize the parameter.
                guard let specialized = self.specialize(type: dl.type, with: dr.type, memo: memo)
                    else { return nil }
                domain.append((label: dl.label, type: specialized))
            }

            // Specialize the codomain.
            guard let codomain = self.specialize(
                type: fnl.codomain, with: fnr.codomain, memo: memo)
                else { return nil }

            // Return the specialized function.
            return FunctionType(from: domain, to: codomain)

        case (let sl as StructType, let sr as StructType):
            guard sl.name == sr.name else { return nil }

            // TODO: Specialize struct types.
            fatalError("TODO")

            // Other pairs either are incompatible types or involve type variables. In both cases,
        // unification will decide how to proceed, so we return the unspecialized type unchanged.
        default:
            return a
        }
    }

    private func specialize(
        type: QualifiedType, with pattern : QualifiedType, memo: Memo) -> QualifiedType?
    {
        guard type.qualifiers.isEmpty
            || pattern.qualifiers.isEmpty
            || (type.qualifiers == pattern.qualifiers)
            else { return nil }
        return self.specialize(type: type.type, with: pattern.type, memo: memo)?
            .qualified(by: type.qualifiers.union(pattern.qualifiers))
    }

    private func specialize(
        type: SemanticType, with mapping: [TypePlaceholder: SemanticType], memo: Memo = Memo())
        -> SemanticType
    {
        switch self.walk(type) {
        case let p as TypePlaceholder:
            return mapping[p] ?? p

        case let f as FunctionType:
            return FunctionType(
                placeholders: f.placeholders.subtracting(mapping.keys),
                from: f.domain.map({
                    ($0.label, self.specialize(type: $0.type, with: mapping, memo: memo))
                }),
                to: self.specialize(type: f.codomain, with: mapping, memo: memo))

        case let s as StructType:
            if let specialized = memo[s] { return specialized }
            let specialized = StructType(
                name: s.name, placeholders: s.placeholders.subtracting(mapping.keys))
            memo[s] = specialized

            for (key, value) in s.properties {
                specialized.properties[key] = self.specialize(
                    type: value, with: mapping, memo: memo)
            }
            for (key, values) in s.methods {
                specialized.methods[key] = values.map {
                    self.specialize(type: $0, with: mapping, memo: memo)
                }
            }

            return specialized

        case let other:
            return other
        }
    }

    private func specialize(
        type: QualifiedType, with mapping: [TypePlaceholder: SemanticType], memo: Memo)
        -> QualifiedType
    {
        return self.specialize(type: type.type, with: mapping, memo: memo)
            .qualified(by: type.qualifiers)
    }

    private func replaceGenericReferences(in type: SemanticType, memo: Memo) -> SemanticType {
        switch self.walk(type) {
        case let f as FunctionType:
            return FunctionType(
                placeholders: f.placeholders,
                from: f.domain.map({
                    ($0.label, self.replaceGenericReferences(in: $0.type, memo: memo))
                }),
                to: self.replaceGenericReferences(in: f.codomain, memo: memo))

        case let s as SelfType:
            // The type pointed by the self container shouldn't be a variable, as we should have
            // already inferred the type it is defined in. Self types can only appear in method
            // signatures, and identifying the type associated with a method requires its owning
            // type to be known (so as to call `find(member:in:)`).
            let walked = self.walk(s.type)
            assert(!(walked is TypeVariable))

            // Make sure the pointed type is generic, otherwise there's nothing to specialize.
            guard let generic = walked as? GenericType else { return walked }

            // Return the type specialization.
            var mapping: [TypePlaceholder: SemanticType] = [:]
            for ph in generic.placeholders {
                if let type = memo[ph] {
                    mapping[ph] = type
                }
            }
            return TypeSpecialization(specializing: generic, with: mapping)

        case let other:
            return other
        }
    }

    private func replaceGenericReferences(in type: QualifiedType, memo: Memo) -> QualifiedType {
        return self.replaceGenericReferences(in: type.type, memo: memo)
            .qualified(by: type.qualifiers)
    }

    private func walk(_ x: SemanticType) -> SemanticType {
        guard let v = x as? TypeVariable else { return x }
        if let walked = self.solution[v] {
            return self.walk(walked)
        } else {
            return v
        }
    }

    private func deepWalk(_ x: SemanticType, memo: Memo) -> SemanticType {
        switch x {
        case let v as TypeVariable:
            if let walked = self.solution[v] {
                return self.deepWalk(walked, memo: memo)
            } else {
                return v
            }

        case let a as TypeAlias:
            return TypeAlias(name: a.name, aliasing: self.deepWalk(a.type, memo: memo))

        case let f as FunctionType:
            return FunctionType(
                placeholders: f.placeholders,
                from: f.domain.map({
                    ($0.label, self.deepWalk($0.type.type, memo: memo)
                        .qualified(by: $0.type.qualifiers))
                }),
                to: self.deepWalk(f.codomain.type, memo: memo)
                    .qualified(by: f.codomain.qualifiers))

        case let s as StructType:
            if let walked = memo[s] { return walked }
            let walked = StructType(name: s.name, placeholders: s.placeholders)
            memo[s] = walked

            for (key, value) in s.properties {
                walked.properties[key] = self.deepWalk(value.type, memo: memo)
                    .qualified(by: value.qualifiers)
            }
            for (key, values) in s.methods {
                walked.methods[key] = values.map { self.deepWalk($0, memo: memo) }
            }

            return walked

        case let s as SelfType:
            return SelfType(aliasing: self.deepWalk(s.type, memo: memo))

        case let s as TypeSpecialization:
            // TODO: Specialize here!
            return TypeSpecialization(
                specializing: self.deepWalk(s.genericType, memo: memo) as! GenericType,
                with: s.specializations)

        default:
            return x
        }
    }

    /// Retrieve the type of the named member(s) of a type.
    private func find(member: String, in type: SemanticType) -> [SemanticType]? {
        switch self.walk(type) {
        case let alias as TypeAlias:
            let members = self.find(member: member, in: alias.type)
            if member == "__new__" {
                return members
            } else {
                return members?.map { ty in
                    FunctionType(
                        from: [(nil, alias.type.qualified(by: .mut))],
                        to  : ty.qualified(by: .cst))
                }
            }

        case let structType as StructType:
            if let propType = structType.properties[member]?.type {
                return [propType]
            } else if let methTypes = structType.methods[member] {
                return methTypes
            } else {
                return []
            }

        case let s as TypeSpecialization:
            return self.find(
                member: member, in: self.specialize(type: s.genericType, with: s.specializations))

        default:
            return nil
        }
    }

    /// A sub-system that defers the current constraint.
    private var deferringCurrentConstraint: ConstraintSystem {
        return ConstraintSystem(
            constraints    : self.constraints.dropFirst() + [self.constraints.first!],
            partialSolution: self.solution)
    }

    private var constraints: [Constraint]
    private var subSystems : [ConstraintSystem] = []
    private var solution   : Solution
    private var done       : Bool = false

}

class Memo: Sequence {

    typealias Element = (key: SemanticType, value: SemanticType)

    init() {
        self.content = []
    }

    func makeIterator() -> Array<Element>.Iterator {
        return self.content.makeIterator()
    }

    subscript(object: SemanticType) -> SemanticType? {
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

    var content: [Element]

}
