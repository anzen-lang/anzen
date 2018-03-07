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

        let memo = TypeMap()
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
        let mapping = TypeMap()
        for ph in unspecialized.placeholders {
            if let specialization = args[ph.name] {
                mapping[ph] = specialization
            }
        }

        // Specialize the function.
        let type = self.deepWalk(a)
        let pattern = self.deepWalk(b)
        guard var specialized = type.specialized(with: pattern, mapping: mapping) else {
            throw InferenceError(reason: "'\(pattern)' is not a specialization of '\(type)'")
        }

        // Because typing with a pattern is a non-linear process, we need to re-apply one
        // specialization pass so to properly bind all inferred generic placeholders.
        specialized = specialized.specialized(with: mapping)
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
    private func unify(_ x: SemanticType, _ y: SemanticType, memo: TypeMap = TypeMap()) throws {
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

    private func walk(_ x: SemanticType) -> SemanticType {
        guard let v = x as? TypeVariable else { return x }
        if let walked = self.solution[v] {
            return self.walk(walked)
        } else {
            return v
        }
    }

    private func deepWalk(_ x: SemanticType, memo: TypeMap = TypeMap()) -> SemanticType {
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
            let mapping = TypeMap(s.specializations.map { ($0.key as SemanticType, $0.value) })
            return self.find(
                member: member,
                in: self.deepWalk(s.genericType).specialized(with: mapping))

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
