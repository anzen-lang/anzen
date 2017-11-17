import os.log
import Parsey

enum Trailer {
    case callArgs([CallArg])
    case subscriptArgs([CallArg])
    case selectOwnee(Ident)
}

public struct Grammar {

    // MARK: Module (entry point of the grammar)

    static let module =
        newlines.? ~~> stmt.* <~~ Lexer.end
        ^^^ { (val, loc) in ModuleDecl(statements: val, location: loc) }

    static let block: Parser<Node> =
        "{" ~~> newlines.? ~~> stmt.* <~~ "}"
        ^^^ { (val, loc) in Block(statements: val, location: loc) }

    static let stmt : Parser<Node> =
        ws.? ~~> stmt_ <~~ (newlines.skipped() | Lexer.character(";").skipped())
    static let stmt_: Parser<Node> =
          block
        | propDecl
        | funDecl
        | structDecl
        | bindingStmt
        | returnStmt
        | expr

    // MARK: Operators

    static let bindingOp =
          Lexer.character("=" ).amid(ws.?) ^^ { _ in Operator.cpy }
        | Lexer.regex    ("&-").amid(ws.?) ^^ { _ in Operator.ref }
        | Lexer.regex    ("<-").amid(ws.?) ^^ { _ in Operator.mov }

    static let notOp = Lexer.regex    ("not").amid(ws.?) ^^ { _ in Operator.not }
    static let mulOp = Lexer.character("*")  .amid(ws.?) ^^ { _ in Operator.mul }
    static let divOp = Lexer.character("/")  .amid(ws.?) ^^ { _ in Operator.div }
    static let modOp = Lexer.character("%")  .amid(ws.?) ^^ { _ in Operator.mod }
    static let addOp = Lexer.character("+")  .amid(ws.?) ^^ { _ in Operator.add }
    static let subOp = Lexer.character("-")  .amid(ws.?) ^^ { _ in Operator.sub }
    static let ltOp  = Lexer.character("<")  .amid(ws.?) ^^ { _ in Operator.lt  }
    static let leOp  = Lexer.regex    ("<=") .amid(ws.?) ^^ { _ in Operator.le  }
    static let gtOp  = Lexer.character(">")  .amid(ws.?) ^^ { _ in Operator.lt  }
    static let geOp  = Lexer.regex    (">=") .amid(ws.?) ^^ { _ in Operator.le  }
    static let eqOp  = Lexer.regex    ("==") .amid(ws.?) ^^ { _ in Operator.eq  }
    static let neOp  = Lexer.regex    ("!=") .amid(ws.?) ^^ { _ in Operator.ne  }
    static let andOp = Lexer.regex    ("and").amid(ws.?) ^^ { _ in Operator.and }
    static let orOp  = Lexer.regex    ("or") .amid(ws.?) ^^ { _ in Operator.or  }

    static func infixOp(_ parser: Parser<Operator>) -> Parser<(Node, Node, SourceRange) -> Node> {
        return parser ^^ { op -> (Node, Node, SourceRange) -> Node in
            return { (left: Node, right: Node, loc: SourceRange) in
                BinExpr(left: left, op: op, right: right, location: loc)
            }
        }
    }

    // MARK: Literals

    static let literal = intLiteral | boolLiteral | strLiteral

    static let intLiteral =
        Lexer.signedInteger
        ^^^ { (val, loc) in Literal(value: Int(val)!, location: loc) as Node }

    static let boolLiteral =
        (Lexer.regex("true") | Lexer.regex("false"))
        ^^^ { (val, loc) in Literal(value: val == "true", location: loc) as Node }

    static let strLiteral =
        Lexer.regex("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"")
        ^^^ { (val, loc) in Literal(value: val, location: loc) as Node }

    // MARK: Expressions

    static let expr     = orExpr
    static let orExpr   = andExpr .infixedLeft(by: infixOp(orOp))
    static let andExpr  = eqExpr  .infixedLeft(by: infixOp(andOp))
    static let eqExpr   = cmpExpr .infixedLeft(by: infixOp(eqOp  | neOp))
    static let cmpExpr  = addExpr .infixedLeft(by: infixOp(ltOp  | leOp  | gtOp  | geOp))
    static let addExpr  = mulExpr .infixedLeft(by: infixOp(addOp | subOp))
    static let mulExpr  = termExpr.infixedLeft(by: infixOp(mulOp | divOp | modOp))
    static let termExpr = prefixExpr | atomExpr

    static let prefixExpr: Parser<Node> =
        (notOp | addOp | subOp) ~~ atomExpr
        ^^^ { (val, loc) in
            let (op, operand) = val
            return UnExpr(op: op, operand: operand, location: loc)
        }

    static let atomExpr: Parser<Node> =
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

    static let atom: Parser<Node> = ifExpr | literal | ident | "(" ~~> expr <~~ ")"

    static let trailer =
          "(" ~~> (callArg.many(separatedBy: comma) <~~ comma.?).? <~~ ")"
            ^^ { val in Trailer.callArgs(val?.map { $0 as! CallArg } ?? []) }
        | "[" ~~> callArg.many(separatedBy: comma) <~~ comma.? <~~ "]"
          ^^ { val in Trailer.subscriptArgs(val.map { $0 as! CallArg }) }
        | "." ~~> ident
          ^^ { val in Trailer.selectOwnee(val as! Ident) }

    static let ifExpr: Parser<Node> =
        "if" ~~> ws ~~> expr ~~ block.amid(ws.?) ~~ elseExpr.?
        ^^^ { (val, loc) in
            return IfExpr(
                condition: val.0.0,
                thenBlock: val.0.1,
                elseBlock: val.1,
                location: loc)
        }

    static let elseExpr: Parser<Node> =
        "else" ~~> ws ~~> (block | ifExpr)

    static let callArg: Parser<Node> =
        (name.? ~~ bindingOp).? ~~ expr
        ^^^ { (val, loc) in
            let (binding, expr) = val
            return CallArg(
                label    : binding?.0,
                bindingOp: binding?.1,
                value    : expr,
                location : loc)
        }

    static let ident: Parser<Node> =
        name
        ^^^ { (val, loc) in Ident(name: val, location: loc) }

    // MARK: Declarations

    /// "function" name [placeholders] "(" [param_decls] ")" ["->" type_sign] block
    static let funDecl: Parser<Node> =
        "function" ~~> ws ~~> name ~~
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
    static let placeholders =
        "<" ~~> name.many(separatedBy: comma) <~~ comma.? <~~ ">"

    /// "(" [param_decl ("," param_decl)* [","]] ")"
    static let paramDecls = "(" ~~> (paramDecl.many(separatedBy: comma) <~~ comma.?).? <~~ ")"

    /// name [name] ":" type_sign
    static let paramDecl: Parser<Node> =
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
    static let propDecl: Parser<Node> =
        "let" ~~> ws ~~> name ~~
        (Lexer.character(":").amid(ws.?) ~~> typeAnnotation).? ~~
        (bindingOp ~~ expr).?
        ^^^ { (val, loc) in
            let (name, sign) = val.0
            let binding = val.1 != nil
                ? (op: val.1!.0, value: val.1!.1 as Node)
                : nil

            return PropDecl(
                name          : name,
                typeAnnotation: sign,
                initialBinding: binding,
                location      : loc)
        }

    /// "struct" name [placeholders] block
    static let structDecl: Parser<Node> =
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

    static let typeAnnotation = qualTypeSign | typeSign

    static let qualTypeSign: Parser<Node> =
        typeQualifier.many(separatedBy: ws) ~~ (ws ~~> typeSign).?
        ^^^ { (val, loc) in
            var qualifiers: TypeQualifier = []
            for q in val.0 {
                qualifiers.formUnion(q)
            }

            return QualSign(qualifiers: qualifiers, signature: val.1, location: loc)
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

    static let typeSign: Parser<Node> =
        ident | funSign | "(" ~~> funSign <~~ ")"

    static let funSign: Parser<Node> =
        "(" ~~> (paramSign.many(separatedBy: comma) <~~ comma.?).? <~~ ")" ~~
        (Lexer.regex("->").amid(ws.?) ~~> typeAnnotation)
        ^^^ { (val, loc) in
            return FunSign(parameters: val.0 ?? [], codomain: val.1, location: loc)
        }

    static let paramSign: Parser<Node> =
        name.? ~~ (Lexer.character(":").amid(ws.?) ~~> typeAnnotation)
        ^^^ { (val, loc) in
            return ParamSign(label: val.0, typeAnnotation: val.1, location: loc)
        }

    // MARK: Statements

    static let bindingStmt: Parser<Node> =
        expr ~~ bindingOp ~~ expr
        ^^^ { (val, loc) in
            return BindingStmt(lvalue: val.0.0, op: val.0.1, rvalue: val.1, location: loc)
        }

    static let returnStmt: Parser<Node> =
        "return" ~~> expr.amid(ws.?).?
        ^^^ { (val, loc) in
            return ReturnStmt(value: val, location: loc)
        }

    // MARK: Other terminal symbols

    static let comment  = Lexer.regex("\\#[^\\n]*")
    static let ws       = Lexer.whitespaces
    static let newlines = (Lexer.newLine | ws.? ~~> comment).+
    static let name     = Lexer.regex("[a-zA-Z_]\\w*")
    static let comma    = Lexer.character(",").amid(ws.?)

}
