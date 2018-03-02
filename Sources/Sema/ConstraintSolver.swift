import AnzenAST
import AnzenTypes

public struct ConstraintSolver: Pass {

    public let name = "semantic type solving"

    public init() {}

    public func run(on module: ModuleDecl) -> [Error] {
        // Extract the type constraints from the AST.
        var extractor = ConstraintExtractor()
        do {
            try extractor.visit(module)
        } catch {
            return [error]
        }

        var binding: [TypeVariable: [SemanticType]] = [:]
        var errors : [Error] = []

        // Solve the type system we built.
        // Note that a program may produce different bindings, hence the loop.
        let constraintSystem = ConstraintSystem(constraints: extractor.constraints)
        while let result = constraintSystem.next() {
            switch result {
            case .solution(let solution):
                for (variable, type) in solution {
                    if binding[variable] == nil {
                        binding[variable] = []
                    }
                    binding[variable]!.append(type)
                }

            case .error(let error):
                errors.append(error)
            }
        }

        // Assign the nodes of the AST to their type.
        var assigner = TypeAssigner(binding: binding, errors: [])
        do {
            try assigner.visit(module)
        } catch {
            return [error]
        }
        guard assigner.errors.isEmpty
            else { return errors + assigner.errors }

        return []
    }

}
