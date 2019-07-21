/// Enumeration of the prefix operators.
public enum PrefixOperator: String, CustomStringConvertible {

  case not
  case add = "+"
  case sub = "-"

  public var description: String {
    return rawValue
  }

}

/// Enumeration of the prefix operators.
public enum InfixOperator: String, CustomStringConvertible {

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
  case peq  = "==="
  case pne  = "!=="
  case `is`

  // MARK: Logical conjunction precedence

  case and

  // MARK: Logical disjunction precedence

  case or

  /// Returns the precedence group of the operator.
  public var precedence: Int {
    switch self {
    case .or:
      return 0
    case .and:
      return 1
    case .eq, .ne, .peq, .pne, .is:
      return 2
    case .lt, .le, .ge, .gt:
      return 3
    case .add, .sub:
      return 4
    case .mul, .div, .mod:
      return 5
    case .as:
      return 6
    }
  }

  public var description: String {
    return rawValue
  }

}

/// Enumeration of the binding operators.
public enum BindingOperator: String, CustomStringConvertible {

  case copy = ":="
  case ref  = "&-"
  case move = "<-"

  public var description: String {
    return rawValue
  }

}
