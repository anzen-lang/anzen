import AnzenTypes
import os.log
import Parsey

public enum Trailer {
    case callArgs([CallArg])
    case subscriptArgs([CallArg])
    case selectOwnee(Ident)
}

public struct Grammar {

    // MARK: Module (entry point of the grammar)

    public static let module =
        newlines.? ~~> stmt.* <~~ Lexer.end
        ^^^ { (val, loc) in ModuleDecl(statements: val, location: loc) }

    public static let block: Parser<Node> =
        "{" ~~> newlines.? ~~> stmt.* <~~ "}"
        ^^^ { (val, loc) in Block(statements: val, location: loc) }

    public static let stmt : Parser<Node> =
        ws.? ~~> stmt_ <~~ (newlines.skipped() | Lexer.character(";").skipped())
    public static let stmt_: Parser<Node> =
          block
        | propDecl
        | funDecl
        | structDecl
        | bindingStmt
        | returnStmt
        | expr

    // MARK: Operators

    public static let bindingOp =
          Lexer.character("=" ).amid(ws.?) ^^ { _ in Operator.cpy }
        | Lexer.regex    ("&-").amid(ws.?) ^^ { _ in Operator.ref }
        | Lexer.regex    ("<-").amid(ws.?) ^^ { _ in Operator.mov }

    public static let notOp = Lexer.regex    ("not").amid(ws.?) ^^ { _ in Operator.not }
    public static let mulOp = Lexer.character("*")  .amid(ws.?) ^^ { _ in Operator.mul }
    public static let divOp = Lexer.character("/")  .amid(ws.?) ^^ { _ in Operator.div }
    public static let modOp = Lexer.character("%")  .amid(ws.?) ^^ { _ in Operator.mod }
    public static let addOp = Lexer.character("+")  .amid(ws.?) ^^ { _ in Operator.add }
    public static let subOp = Lexer.character("-")  .amid(ws.?) ^^ { _ in Operator.sub }
    public static let ltOp  = Lexer.character("<")  .amid(ws.?) ^^ { _ in Operator.lt  }
    public static let leOp  = Lexer.regex    ("<=") .amid(ws.?) ^^ { _ in Operator.le  }
    public static let gtOp  = Lexer.character(">")  .amid(ws.?) ^^ { _ in Operator.lt  }
    public static let geOp  = Lexer.regex    (">=") .amid(ws.?) ^^ { _ in Operator.le  }
    public static let eqOp  = Lexer.regex    ("==") .amid(ws.?) ^^ { _ in Operator.eq  }
    public static let neOp  = Lexer.regex    ("!=") .amid(ws.?) ^^ { _ in Operator.ne  }
    public static let andOp = Lexer.regex    ("and").amid(ws.?) ^^ { _ in Operator.and }
    public static let orOp  = Lexer.regex    ("or") .amid(ws.?) ^^ { _ in Operator.or  }

    public static func infixOp(_ parser: Parser<Operator>)
        -> Parser<(Node, Node, SourceRange) -> Node>
    {
        return parser ^^ { op -> (Node, Node, SourceRange) -> Node in
            return { (left: Node, right: Node, loc: SourceRange) in
                BinExpr(left: left, op: op, right: right, location: loc)
            }
        }
    }

    // MARK: Literals

    public static let literal = intLiteral | boolLiteral | strLiteral

    static let intLiteral =
        Lexer.signedInteger
        ^^^ { (val, loc) in Literal(value: Int(val)!, location: loc) as Node }

    public static let boolLiteral =
        (Lexer.regex("true") | Lexer.regex("false"))
        ^^^ { (val, loc) in Literal(value: val == "true", location: loc) as Node }

    public static let strLiteral =
        Lexer.regex("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"")
        ^^^ { (val, loc) in Literal(value: val, location: loc) as Node }

    // MARK: Expressions

    public static let expr     = orExpr
    public static let orExpr   = andExpr .infixedLeft(by: infixOp(orOp))
    public static let andExpr  = eqExpr  .infixedLeft(by: infixOp(andOp))
    public static let eqExpr   = cmpExpr .infixedLeft(by: infixOp(eqOp  | neOp))
    public static let cmpExpr  = addExpr .infixedLeft(by: infixOp(ltOp  | leOp  | gtOp  | geOp))
    public static let addExpr  = mulExpr .infixedLeft(by: infixOp(addOp | subOp))
    public static let mulExpr  = termExpr.infixedLeft(by: infixOp(mulOp | divOp | modOp))
    public static let termExpr = prefixExpr | atomExpr

    public static let prefixExpr: Parser<Node> =
        (notOp | addOp | subOp) ~~ atomExpr
        ^^^ { (val, loc) in
            let (op, operand) = val
            return UnExpr(op: op, operand: operand, location: loc)
        }

    public static let atomExpr: Parser<Node> =
        atom ~~ trailer.*
        ^^^ { (val, loc) in
            let (atom, trailers) = val

            // Trailers are the expression "suffixes" that get parsed after an atom expression.
            // They may represent a list of call/subscript arguments or the ownee expressions.
            // Trailers are left-associative, i.e. `f(x)[y].z` is parsed `((f(x))[y]).z`.
            return trailers.reduce(atom) { result, trailer in
                switch trailer {
                case let .callArgs(args):
                    return CallExpr(callee: result, arguments: args, location: loc)
                case let .subscriptArgs(args):
                    return SubscriptExpr(callee: result, arguments: args, location: loc)
                case let .selectOwnee(ownee):
                    return SelectExpr(owner: result, ownee: ownee, location: loc)
                }
            }
        }

    public static let atom: Parser<Node> = ifExpr | literal | ident | "(" ~~> expr <~~ ")"

    public static let trailer =
          "(" ~~> (callArg.many(separatedBy: comma) <~~ comma.?).? <~~ ")"
            ^^ { val in Trailer.callArgs(val?.map { $0 as! CallArg } ?? []) }
        | "[" ~~> callArg.many(separatedBy: comma) <~~ comma.? <~~ "]"
          ^^ { val in Trailer.subscriptArgs(val.map { $0 as! CallArg }) }
        | "." ~~> ident
          ^^ { val in Trailer.selectOwnee(val as! Ident) }

    public static let ifExpr: Parser<Node> =
        "if" ~~> ws ~~> expr ~~ block.amid(ws.?) ~~ elseExpr.?
        ^^^ { (val, loc) in
            return IfExpr(
                condition: val.0.0,
                thenBlock: val.0.1,
                elseBlock: val.1,
                location: loc)
        }

    public static let elseExpr: Parser<Node> =
        "else" ~~> ws ~~> (block | ifExpr)

    public static let callArg: Parser<Node> =
        (name.? ~~ bindingOp).? ~~ expr
        ^^^ { (val, loc) in
            let (binding, expr) = val
            return CallArg(
                label    : binding?.0,
                bindingOp: binding?.1,
                value    : expr,
                location : loc)
        }

    public static let ident: Parser<Node> =
        name
        ^^^ { (val, loc) in Ident(name: val, location: loc) }

    // MARK: Declarations

    /// "function" name [placeholders] "(" [param_decls] ")" ["->" type_sign] block
    public static let funDecl: Parser<Node> =
        "fun" ~~> ws ~~> name ~~
        placeholders.amid(ws.?).? ~~
        paramDecls.amid(ws.?) ~~
        (Lexer.regex("->").amid(ws.?) ~~> typeAnnotation).amid(ws.?).? ~~
        block
        ^^^ { (val, loc) in
            return FunDecl(
                name        : val.0.0.0.0,
                placeholders: val.0.0.0.1 ?? [],
                parameters  : val.0.0.1?.map { $0 as! ParamDecl } ?? [],
                codomain    : val.0.1,
                body        : val.1 as! Block,
                location    : loc)
        }

    /// "<" name ("," name)* [","] ">"
    public static let placeholders =
        "<" ~~> name.many(separatedBy: comma) <~~ comma.? <~~ ">"

    /// "(" [param_decl ("," param_decl)* [","]] ")"
    public static let paramDecls = "(" ~~> (paramDecl.many(separatedBy: comma) <~~ comma.?).? <~~ ")"

    /// name [name] ":" type_sign
    public static let paramDecl: Parser<Node> =
        name ~~ name.amid(ws.?).? ~~
        (Lexer.character(":").amid(ws.?) ~~> typeAnnotation)
        ^^^ { (val, loc) in
            let (interface, sign) = val
            let (label    , name) = interface
            return ParamDecl(
                label         : label != "_" ? label : nil,
                name          : name ?? label,
                typeAnnotation: sign)
        }

    /// "let" name [":" type_sign] [assign_op expr]
    public static let propDecl: Parser<Node> =
        (Lexer.regex("let") | Lexer.regex("var")) ~~
        (ws ~~> name) ~~
        (Lexer.character(":").amid(ws.?) ~~> typeAnnotation).? ~~
        (bindingOp ~~ expr).?
        ^^^ { (val, loc) in
            let (declType, name) = val.0.0
            let sign = val.0.1
             let binding = val.1 != nil
                 ? (op: val.1!.0, value: val.1!.1 as Node)
                 : nil

             return PropDecl(
                 name          : name,
                 reassignable  : declType == "var",
                 typeAnnotation: sign,
                 initialBinding: binding,
                 location      : loc)
        }

    /// "struct" name [placeholders] block
    public static let structDecl: Parser<Node> =
        "struct" ~~> name.amid(ws.?) ~~
        placeholders.amid(ws.?).? ~~
        block
        ^^^ { (val, loc) in
            return StructDecl(
                name        : val.0.0,
                placeholders: val.0.1 ?? [],
                body        : val.1 as! Block,
                location    : loc)
        }

    // MARK: Type signatures

    public static let typeAnnotation = qualTypeSign | typeSign

    public static let qualTypeSign: Parser<Node> =
        typeQualifier.many(separatedBy: ws) ~~ (ws ~~> typeSign).?
        ^^^ { (val, loc) in
            var qualifiers: TypeQualifier = []
            for q in val.0 {
                qualifiers.formUnion(q)
            }

            return QualSign(qualifiers: qualifiers, signature: val.1, location: loc)
        }

    public static let typeQualifier: Parser<TypeQualifier> = "@" ~~> name
        ^^ { val in
            switch val {
            case "cst": return .cst
            case "mut": return .mut
            default:
                print("warning: unexpected qualifier: '\(val)'")
                return []
            }
        }

    public static let typeSign: Parser<Node> =
        ident | funSign | "(" ~~> funSign <~~ ")"

    public static let funSign: Parser<Node> =
        "(" ~~> (paramSign.many(separatedBy: comma) <~~ comma.?).? <~~ ")" ~~
        (Lexer.regex("->").amid(ws.?) ~~> typeAnnotation)
        ^^^ { (val, loc) in
            return FunSign(parameters: val.0 ?? [], codomain: val.1, location: loc)
        }

    public static let paramSign: Parser<Node> =
        name.? ~~ (Lexer.character(":").amid(ws.?) ~~> typeAnnotation)
        ^^^ { (val, loc) in
            return ParamSign(label: val.0, typeAnnotation: val.1, location: loc)
        }

    // MARK: Statements

    public static let bindingStmt: Parser<Node> =
        expr ~~ bindingOp ~~ expr
        ^^^ { (val, loc) in
            return BindingStmt(lvalue: val.0.0, op: val.0.1, rvalue: val.1, location: loc)
        }

    public static let returnStmt: Parser<Node> =
        "return" ~~> expr.amid(ws.?).?
        ^^^ { (val, loc) in
            return ReturnStmt(value: val, location: loc)
        }

    // MARK: Other terminal symbols

    public static let comment  = Lexer.regex("\\#[^\\n]*")
    public static let ws       = Lexer.whitespaces
    public static let newlines = (Lexer.newLine | ws.? ~~> comment).+
    public static let name     = Lexer.regex("[a-zA-Z_]\\w*")
    public static let comma    = Lexer.character(",").amid(ws.?)

}
