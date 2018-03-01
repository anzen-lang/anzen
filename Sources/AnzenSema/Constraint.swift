import AnzenAST
import AnzenTypes
import Parsey

public enum Constraint {

    // MARK: Type constraints

    /// An equality constraint.
    case equals(type: SemanticType, to: SemanticType, at: SourceRange?)

    /// A conformance constraint.
    ///
    /// Conformance can be seen as a weaker equivalence relationship between two types, stating
    /// that they should be equivalent with respect to their interface, but not necessarily their
    /// semantics.
    case conforms(type: SemanticType, to: SemanticType, at: SourceRange?)

    /// A specialization constraint.
    ///
    /// Specilization can be seen as a weaker conformance relationship between two types, stating
    /// that one should conform to the other for a given binding of type placeholders.
    case specializes(
        type: SemanticType, with: SemanticType, using: [String: SemanticType],
        at: SourceRange?)

    // MARK: Membership constraints

    case belongs(symbol: Symbol, to: SemanticType, at: SourceRange?)

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
