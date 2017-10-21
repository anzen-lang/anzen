import os.log
import Parsey

enum Trailer {
    case callArgs([Node])
    case subscriptArgs([Node])
    case selectMember(Node)
}

public struct Grammar {

    // MARK: Module (entry point of the grammar)

    public static let module = newlines.* ~~> stmt.* <~~ Lexer.end
        ^^^ { (val, loc) in Module(statements: val, location: loc) }

    // static let stmt = propDecl <~~ newlines
    static let stmt = expr <~~ newlines

    // MARK: Operators

    static let bindingOp =
          Lexer.character("=" ) ^^ { _ in Operator.cpy }
        | Lexer.regex    ("&-") ^^ { _ in Operator.ref }
        | Lexer.regex    ("<-") ^^ { _ in Operator.mov }

    static let notOp = Lexer.regex    ("not").amid(whitespaces.?) ^^ { _ in Operator.not }
    static let mulOp = Lexer.character("*")  .amid(whitespaces.?) ^^ { _ in Operator.mul }
    static let divOp = Lexer.character("/")  .amid(whitespaces.?) ^^ { _ in Operator.div }
    static let modOp = Lexer.character("%")  .amid(whitespaces.?) ^^ { _ in Operator.mod }
    static let addOp = Lexer.character("+")  .amid(whitespaces.?) ^^ { _ in Operator.add }
    static let subOp = Lexer.character("-")  .amid(whitespaces.?) ^^ { _ in Operator.sub }
    static let ltOp  = Lexer.character("<")  .amid(whitespaces.?) ^^ { _ in Operator.lt  }
    static let leOp  = Lexer.regex    ("<=") .amid(whitespaces.?) ^^ { _ in Operator.le  }
    static let gtOp  = Lexer.character(">")  .amid(whitespaces.?) ^^ { _ in Operator.lt  }
    static let geOp  = Lexer.regex    (">=") .amid(whitespaces.?) ^^ { _ in Operator.le  }
    static let eqOp  = Lexer.regex    ("==") .amid(whitespaces.?) ^^ { _ in Operator.eq  }
    static let neOp  = Lexer.regex    ("!=") .amid(whitespaces.?) ^^ { _ in Operator.ne  }
    static let andOp = Lexer.regex    ("and").amid(whitespaces.?) ^^ { _ in Operator.and }
    static let orOp  = Lexer.regex    ("or") .amid(whitespaces.?) ^^ { _ in Operator.or  }

    static func infixOp(_ parser: Parser<Operator>) -> Parser<(Node, Node, SourceRange) -> Node> {
        return parser ^^ { op -> (Node, Node, SourceRange) -> Node in
            return { (left: Node, right: Node, loc: SourceRange) in
                BinExpr(left: left, op: op, right: right, location: loc)
            }
        }
    }

    // MARK: Literals

    static let literal = intLiteral

    static let intLiteral = Lexer.signedInteger
        ^^^ { (val, loc) in IntLiteral(value: Int(val)!, location: loc) as Node }

    // MARK: Expressions

    static let expr = orExpr

    static let orExpr   = andExpr .infixedLeft(by: infixOp(orOp))
    static let andExpr  = eqExpr  .infixedLeft(by: infixOp(andOp))
    static let eqExpr   = cmpExpr .infixedLeft(by: infixOp(eqOp  | neOp))
    static let cmpExpr  = addExpr .infixedLeft(by: infixOp(ltOp  | leOp  | gtOp  | geOp))
    static let addExpr  = mulExpr .infixedLeft(by: infixOp(addOp | subOp))
    static let mulExpr  = termExpr.infixedLeft(by: infixOp(mulOp | divOp | modOp))
    static let termExpr = prefixExpr | atomExpr

    static let prefixExpr: Parser<Node> = (notOp | addOp | subOp) ~~ atomExpr
        ^^^ { (val, loc) in
            let (op, operand) = val
            return UnExpr(op: op, operand: operand, location: loc)
        }

    static let atomExpr: Parser<Node> = atom ~~ trailer.*
        ^^^ { (val, loc) in
            let (atom, trailers) = val

            // Trailers are the expression "suffixes" that get parsed after an atom expression.
            // They may represent a list of call/subscript arguments or the member expressions.
            // Trailers are left-associative, i.e. `f(x)[y].z` is parsed `((f(x))[y]).z`.
            return trailers.reduce(atom) { result, trailer in
                switch trailer {
                case let .callArgs(args):
                    return CallExpr(callee: result, arguments: args, location: loc)
                case let .subscriptArgs(args):
                    return SubscriptExpr(callee: result, arguments: args, location: loc)
                case let .selectMember(member):
                    return SelectExpr(owner: result, member: member, location: loc)
                }
            }
        }

    static let atom: Parser<Node> = ident | literal | "(" ~~> expr <~~ ")"

    static let trailer =
          "(" ~~> (callArg.many(separatedBy: comma) <~~ comma.?).? <~~ ")"
          ^^ { val in Trailer.callArgs(val ?? []) }
        | "[" ~~> callArg.many(separatedBy: comma) <~~ comma.? <~~ "]"
          ^^ { val in Trailer.subscriptArgs(val) }
        | "." ~~> ident
          ^^ { val in Trailer.selectMember(val) }

    static let callArg: Parser<CallArg> =
        (name.? ~~ bindingOp.amid(whitespaces.?)).? ~~ expr
        ^^^ { (val, loc) in
            let (binding, expr) = val
            return CallArg(
                label    : binding?.0,
                bindingOp: binding?.1,
                value    : expr,
                location : loc)
        }

    static let ident = name
        ^^^ { (val, loc) in Ident(name: val, location: loc) as Node }

    // MARK: Declarations

    static let propDecl: Parser<PropDecl> =
        "let" ~~> whitespaces ~~> name ~~
        (Lexer.character(":").amid(whitespaces.?) ~~> typeAnnot).? ~~
        (bindingOp.amid(whitespaces.?) ~~ expr).?
        ^^^ { (val, loc) in
            let (name, annot) = val.0
            let binding = val.1 != nil
                ? (op: val.1!.0, value: val.1!.1 as Node)
                : nil

            return PropDecl(
                name          : name,
                typeAnnotation: annot,
                initialBinding: binding,
                location      : loc)
        }

    // MARK: Type annotations

    static let typeAnnot: Parser<TypeAnnot> = qualTypeAnnot | unqualTypeAnnot

    static let unqualTypeAnnot: Parser<TypeAnnot> = ident
        ^^^ { (val, loc) in
            return TypeAnnot(qualifiers: [], signature: val, location: loc)
        }

    static let qualTypeAnnot: Parser<TypeAnnot> =
        typeQualifier.many(separatedBy: whitespaces) <~~ whitespaces ~~ ident.?
        ^^^ { (val, loc) in
            var qualifiers: TypeQualifier = []
            for q in val.0 {
                qualifiers.formUnion(q)
            }

            return TypeAnnot(qualifiers: qualifiers, signature: val.1, location: loc)
        }

    static let typeQualifier: Parser<TypeQualifier> = "@" ~~> name
        ^^ { val in
            switch val {
            case "cst": return .cst
            case "mut": return .mut
            case "stk": return .stk
            case "shd": return .shd
            case "val": return .val
            case "ref": return .ref
            default:
                print("warning: unexpected qualifier: '\(val)'")
                return []
            }
        }

    // MARK: Other terminal symbols

    static let comment      = Lexer.regex("\\#[^\\n]*")
    static let newlines     = (Lexer.newLine | comment).+
    static let whitespaces  = Lexer.whitespaces
    static let name         = Lexer.regex("[a-zA-Z_]\\w*")
    static let comma        = Lexer.character(",").amid(whitespaces.?)

}
