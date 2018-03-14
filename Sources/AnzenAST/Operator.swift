/// Enumeration of the prefix operators.
public enum PrefixOperator: String {

    case not
    case add  = "+"
    case sub  = "-"

}

/// Enumeration of the prefix operators.
public enum InfixOperator: String {

    // MARK: Casting precedence

    case `as`

    // MARK: Multiplication precedence

    case mul  = "*"
    case div  = "/"
    case mod  = "%"

    // MARK: Addition precedence

    case add  = "+"
    case sub  = "-"

    // MARK: Comparison precedence

    case lt   = "<"
    case le   = "<="
    case ge   = ">="
    case gt   = ">"

    // MARK: Equivalence precedence

    case eq   = "=="
    case ne   = "!="
    case `is`

    // MARK: Logical conjunction precedence

    case and

    // MARK: Logical disjunction precedence

    case or

}

/// Enumeration of the binding operators.
public enum BindingOperator: String {

    case copy = "="
    case ref  = "&-"
    case move = "<-"

}
