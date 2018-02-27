import AnzenAST
import AnzenTypes

public enum Constraint {

    // MARK: Type constraints

    case equals     (type: SemanticType, to  : SemanticType)
    case conforms   (type: SemanticType, to  : SemanticType)
    case specializes(type: SemanticType, with: SemanticType, using: [String: SemanticType])

    // MARK: Membership constraints

    case belongs(symbol: Symbol, to: SemanticType)

    // MARK: Disjunctions

    indirect case disjunction([Constraint])

    public static func or<S>(_ constraints: S) -> Constraint
        where S: Sequence, S.Element == Constraint
    {
        let a = Array(constraints)
        return a.count == 1 ? a.first! : .disjunction(a)
    }

    public static func || (lhs: Constraint, rhs: Constraint) -> Constraint {
        switch (lhs, rhs) {
        case (.disjunction(let ld), .disjunction(let rd)): return .or(ld + rd)
        case (.disjunction(let ld), _)                   : return .disjunction(ld + [rhs])
        case (_, .disjunction(let rd))                   : return .or([lhs] + rd)
        case (_, _)                                      : return .or([lhs, rhs])
        }
    }

}
