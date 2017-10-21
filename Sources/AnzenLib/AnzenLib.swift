import os.log
import Parsey

public struct Grammar {

    // MARK: Module (entry point of the grammar)

    public static let module = newlines.* ~~> stmt.* <~~ Lexer.end
        ^^^ { (val, loc) in Module(statements: val, location: loc) }

    static let stmt = propDecl <~~ newlines

    // MARK: Operators

    static let bindingOp =
          Lexer.character("=" ) ^^ { _ in Operator.cpy }
        | Lexer.regex    ("&-") ^^ { _ in Operator.ref }
        | Lexer.regex    ("<-") ^^ { _ in Operator.mov }

    // MARK: Literals

    static let intLiteral = Lexer.signedInteger
        ^^^ { (val, loc) in IntLiteral(value: Int(val)!, location: loc) }

    // MARK: Expressions

    public static let callExpr: Parser<Node> =
        atom.suffixed(by: "(" ~~> callArgs <~~ ")")

    static let callArgs =
        (callArg.many(separatedBy: comma) <~~ comma.?).?
        ^^^ { (args, loc) in
            return { CallExpr(callee: $0, arguments: args ?? [], location: loc) as Node }
        }

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
        ^^^ { (val, loc) in Ident(name: val, location: loc) }

    static let atom: Parser<Node> =
          ident      ^^ { $0 as Node }
        | intLiteral ^^ { $0 as Node }
        | "(" ~~> expr <~~ ")"

    static let expr = callExpr | atom

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
