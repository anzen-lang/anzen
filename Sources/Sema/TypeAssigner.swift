import AnzenAST
import AnzenTypes

struct TypeAssigner: ASTVisitor {

    mutating func visit(_ node: FunDecl) throws {
        try self.traverse(node)
        self.setType(of: node)
    }

    mutating func visit(_ node: ParamDecl) throws {
        try self.traverse(node)
        self.setType(of: node)
    }

    mutating func visit(_ node: PropDecl) throws {
        try self.traverse(node)
        self.setType(of: node)
    }

    mutating func visit(_ node: StructDecl) throws {
        try self.traverse(node)
        self.setType(of: node)
    }

    mutating func visit(_ node: InterfaceDecl) throws {
        try self.traverse(node)
        self.setType(of: node)
    }

    mutating func visit(_ node: PropReq) throws {
        try self.traverse(node)
        self.setType(of: node)
    }

    mutating func visit(_ node: FunReq) throws {
        try self.traverse(node)
        self.setType(of: node)
    }

    mutating func visit(_ node: QualSign) throws {
        try self.traverse(node)
        self.setType(of: node)
    }

    mutating func visit(_ node: FunSign) throws {
        try self.traverse(node)
        self.setType(of: node)
    }

    mutating func visit(_ node: ParamSign) throws {
        try self.traverse(node)
        self.setType(of: node)
    }

    mutating func visit(_ node: IfExpr) throws {
        try self.traverse(node)
        self.setType(of: node)
    }

    mutating func visit(_ node: BinExpr) throws {
        try self.traverse(node)
        self.setType(of: node)
    }

    mutating func visit(_ node: UnExpr) throws {
        try self.traverse(node)
        self.setType(of: node)
    }

    mutating func visit(_ node: CallExpr) throws {
        try self.traverse(node)
        self.setType(of: node)
    }

    mutating func visit(_ node: CallArg) throws {
        try self.traverse(node)
        self.setType(of: node)
    }

    mutating func visit(_ node: SubscriptExpr) throws {
        try self.traverse(node)
        self.setType(of: node)
    }

    mutating func visit(_ node: SelectExpr) throws {
        try self.traverse(node)
        self.setType(of: node)
    }

    mutating func visit(_ node: Ident) throws {
        try self.traverse(node)
        self.setType(of: node)
    }

    mutating func setType(of node: TypedNode) {
        if let t = node.type as? TypeVariable {
            switch self.binding[t] {
            case let assignments? where assignments.count == 1:
                node.type = assignments[0]

            case let assignments?:
                node.type = TypeError()
                let expr = (node as? NamedNode)?.name ?? node.description
                self.errors.append(
                    AmbiguousType(expr: expr, candidates: assignments))

            default:
                node.type = TypeError()
                let expr = (node as? NamedNode)?.name ?? node.description
                self.errors.append(
                    InferenceError(
                        reason: "Couldn't infer the type of \(expr).", location: node.location))
            }
        }
    }

    let binding: [TypeVariable: [SemanticType]]
    var errors: [Error]

}
