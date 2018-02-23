import AnzenAST
import AnzenTypes

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
            switch constraint {
            case .equals(let x, let y):
                do {
                    try self.solveEquality(between: x, and: y)
                } catch {
                    return .error(error)
                }

            case .conforms(let x, let y):
                // TODO: For the time being, we process conformance constraint the same way we
                // process equality constraints. However, when we'll implement interfaces, we'll
                // have to use a different kind of unification. Moreover, this will probably
                // require some knowledge on the type profiles to have already been inferred.
                do {
                    try self.solveEquality(between: x, and: y)
                } catch {
                    return .error(error)
                }

            case .specializes(let x, let y):
                do {
                    try self.solveSpecialization(of: x, with: y)
                } catch {
                    return .error(error)
                }

            // Membership constraints require the profile of the owning type to have already been
            // inferred. When that's the case, it can be solved immediately, unless the targetted
            // member is overloaded, in which case a sub-system will be created with a disjunction
            // of constraints for each of the overloads. If the owning type hasn't been inferred
            // yet, the constraint is deferred.
            case .belongs(let symbol, let type):
                do {
                    try self.solveMembership(of: symbol, in: type)
                } catch {
                    return .error(error)
                }

            // A disjunction of constraints represents possible backtracking points. Whenever we
            // encounter one, we explore all solutions that can be produced for each choice in
            // sub-systems containing that should solve the remaining constraints.
            case .disjunction(let choices):
                self.subSystems = choices.map {
                    ConstraintSystem(
                        constraints    : self.constraints + [$0],
                        partialSolution: self.solution)
                }

                self.constraints = []
                self.done        = true
                return self.subSystems.first?.next()
            }
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

    private func solveEquality(between x: SemanticType, and y: SemanticType) throws {
        let a = self.walk(x)
        let b = self.walk(y)

        // Unifying a type alias with a function type isn't necessary inconsistent. It may happen
        // when a equality constraint is placed on a callee that represents a type initializer. In
        // that case, instead of unifying both types, we must look for the type's initializers and
        // try to unify each of them.
        if let fun = a as? FunctionType, let alias = b as? TypeAlias {
            guard let initializers = self.find(member: "__new__", in: alias.type) else {
                self.constraints.insert(.equals(type: a, to: b), at: 0)
                return
            }
            guard !initializers.isEmpty else {
                let walked = self.walk(alias.type)
                throw InferenceError(reason: "'\(walked)' has no initializer")
            }

            self.constraints.append(.or(initializers.map({
                Constraint.equals(type: fun, to: $0)
            })))
            return
        }

        try self.unify(x, y)
    }

    private func solveSpecialization(of x: SemanticType, with y: SemanticType) throws {
        let a = self.walk(x)
        let b = self.walk(y)

        guard !(a is TypeVariable) else {
            self.constraints.insert(.specializes(type: a, with: b), at: 0)
            return
        }
        guard let specialized = self.specialize(type: a, with: b) else {
            throw InferenceError(reason: "'\(a)' is not a specialization of '\(b)'")
        }

        try self.solveEquality(between: b, and: specialized)
    }

    private func solveMembership(of symbol: Symbol, in type: SemanticType) throws {
        // FIXME: Deep walk the type.
        guard let members = self.find(member: symbol.name, in: type) else {
            self.constraints.insert(.belongs(symbol: symbol, to: type), at: 0)
            return
        }
        guard !members.isEmpty else {
            let walked = self.walk(type)
            throw InferenceError(reason: "'\(walked)' has no member '\(symbol.name)'")
        }

        self.constraints.append(.or(members.map({
            Constraint.equals(type: symbol.type, to: $0)
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

    /// Attempts to specialize `y` so that it is compatible with `x`.
    private func specialize(type x: SemanticType, with y: SemanticType, memo: Memo = Memo())
        -> SemanticType?
    {
        let a = self.walk(x)
        let b = self.walk(y)

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

            var domain: [FunctionType.ParameterDescription] = []
            for (dl, dr) in zip(fnl.domain, fnr.domain) {
                // Make sure the labels are identical.
                guard dl.label == dr.label else { return nil }

                // Make sure the parameters' qualifiers are identical (if any).
                guard  dl.type.qualifiers.isEmpty
                    || dr.type.qualifiers.isEmpty
                    || dl.type.qualifiers == dr.type.qualifiers else { return nil }

                // Specialize the parameter.
                guard let specialized = self.specialize(
                    type: dl.type.type, with: dr.type.type, memo: memo) else { return nil }
                domain.append((
                    dl.label,
                    specialized.qualified(by: dl.type.qualifiers.union(dr.type.qualifiers))))
            }

            // Make sure the codomains' qualifiers are identical (if any)
            guard  fnl.codomain.qualifiers.isEmpty
                || fnr.codomain.qualifiers.isEmpty
                || fnl.codomain.qualifiers == fnr.codomain.qualifiers else { return nil }

            // Specialize the codomain
            guard let codomain = self.specialize(
                type: fnl.codomain.type, with: fnr.codomain.type, memo: memo) else { return nil }

            return FunctionType(
                from: domain,
                to  : codomain.qualified(
                    by: fnl.codomain.qualifiers.union(fnr.codomain.qualifiers)))

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

        default:
            return x
        }
    }

    /// Retrieve the type of the named member(s) of a type.
    private func find(member: String, in type: SemanticType) -> [SemanticType]? {
        switch self.walk(type) {
        case let alias as TypeAlias:
            guard let members = self.find(member: member, in: alias.type) else { return nil }
            return members.map { ty in
                FunctionType(
                    from: [(nil, alias.type.qualified(by: .mut))],
                    to  : ty.qualified(by: .cst))
            }

        case let structType as StructType:
            if let propType = structType.properties[member]?.type {
                return [propType]
            } else if let methTypes = structType.methods[member] {
                return methTypes
            } else {
                return []
            }

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

fileprivate class Memo: Sequence {

    typealias Element = (key: AnyObject, value: SemanticType)

    var content: [Element] = []

    func makeIterator() -> Array<Element>.Iterator {
        return self.content.makeIterator()
    }

    subscript(object: AnyObject) -> SemanticType? {
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

}
