public enum Operator: CustomStringConvertible {

    case not
    case mul , div , mod
    case add , sub
    case lt  , le  , gt  , ge
    case eq  , ne
    case and
    case or
    case cpy , ref , mov

    // MARK: Pretty-printing

    public var description: String {
        return Operator.repr[self]!
    }

    public static var repr: [Operator: String] = [
        .not : "not",
        .mul : "*"  , .div : "/"  , .mod : "%"  ,
        .add : "+"  , .sub : "-"  ,
        .lt  : "<"  , .le  : "<=" , .gt  : ">"  , .ge:  ">=" ,
        .eq  : "==" , .ne  : "!=" ,
        .and : "and",
        .or  : "or" ,
        .cpy : "="  , .ref : "&-" , .mov : "<-" ,
    ]

}
