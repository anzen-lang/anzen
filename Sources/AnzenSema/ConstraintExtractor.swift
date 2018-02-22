import AnzenAST
import AnzenTypes

public struct ConstraintExtractor: ASTVisitor {

    public init() {}

    public mutating func visit(_ node: FunDecl) throws {
        // Extract the function's domain.
        var domain: [(label: String?, type: QualifiedType)] = []
        for parameter in node.parameters {
            try self.visit(parameter)
            domain.append((parameter.label, parameter.type!.qualified(by: parameter.qualifiers)))
        }

        // The codomain is either a signature we've to read, or `Nothing`.
        let codomain = node.codomain != nil
            ? try analyzeTypeAnnotation(node.codomain!)
            : Builtins.instance.Nothing.qualified(by: .cst)

        // Once we've computed the domain and codomain of the function's signature, we can create
        // a type for the function itself.
        let functionType = FunctionType(
            placeholders: Set(node.placeholders), from: domain, to: codomain)

        // Visit the body of the function.
        try self.visit(node.body)

        // Add an equality constraint on the symbol's type.
        self.constraints.append(.equals(node.type!, functionType))
    }

    public mutating func visit(_ node: ParamDecl) throws {
        // Extract the type of the parameter from its annotation.
        let annotation  = try analyzeTypeAnnotation(node.typeAnnotation)
        node.qualifiers = annotation.qualifiers

        // Add an equality constraint on the symbol's type.
        self.constraints.append(.equals(node.type!, annotation.type))
    }

    public mutating func visit(_ node: PropDecl) throws {
        // Infer the type of the property from its annotation (if any).
        if let typeAnnotation = node.typeAnnotation {
            let annotation  = try analyzeTypeAnnotation(typeAnnotation)
            node.qualifiers = annotation.qualifiers

            // Add an equality constraint on the symbol's type.
            self.constraints.append(.equals(node.type!, annotation.type))
        } else {
            node.qualifiers = [.cst]
        }

        // Infer the type of the binding value (if any).
        if let (_, initialValue) = node.initialBinding {
            try self.visit(initialValue)
            let valueTy = (initialValue as! TypedNode).type!

            // If there's a type annotation, add a conformance constraint, as the property might
            // be declared as a super type of its initial value. Otherwise, add an equality
            // constraint.
            if node.typeAnnotation != nil {
                self.constraints.append(.conforms(node.type!, valueTy))
            } else {
                self.constraints.append(.equals(node.type!, valueTy))
            }
        }
    }

    public mutating func visit(_ node: StructDecl) throws {
        // Create a new type for the struct.
        let structType = StructType(name: node.name, placeholders: Set(node.placeholders))

        // Infer the type of all members of the struct.
        for child in node.body.statements {
            try self.visit(child)
            switch child {
            case let property as PropDecl:
                structType.properties[property.name] =
                    property.type!.qualified(by: property.qualifiers)
            case let method as FunDecl:
                if structType.methods[method.name] == nil {
                    structType.methods[method.name] = []
                }
                structType.methods[method.name]?.append(method.type!)
            default:
                assertionFailure("unreachable")
            }
        }

        let alias = node.type as? TypeAlias
        self.constraints.append(.equals(alias!.type, structType))
    }

    public mutating func visit(_ node: BindingStmt) throws {
        try self.visit(node.lvalue)
        try self.visit(node.rvalue)
        self.constraints.append(
            .conforms((node.lvalue as! TypedNode).type!, (node.rvalue as! TypedNode).type!))
    }

    public mutating func visit(_ node: CallExpr) throws {
        // Infer the type of all arguments and build the domain of the function being called.
        var domain: [FunctionType.ParameterDescription] = []
        for argument in node.arguments {
            try self.visit(argument)
            domain.append((label: argument.label, type: argument.type!.qualified(by: [])))
        }

        // Create a fresh variable for the node, and use it as the function's codomain.
        node.type = TypeVariable()
        let codomain = node.type!.qualified(by: [])

        // Create a new function type for the callee.
        let functionType = FunctionType(from: domain, to: codomain)

        // Infer the type of the callee, and create an equality constraint with the function we
        // just created.
        try self.visit(node.callee)
        self.constraints.append(.equals((node.callee as! TypedNode).type!, functionType))
    }

    public mutating func visit(_ node: SelectExpr) throws {
        // Create a new symbol for the ownee, and use its type as that of the expression.
        node.ownee.symbol = Symbol(name: node.ownee.name)
        node.type = node.ownee.symbol!.type

        // If the expression has an owner, add a membership constraint on its type for the symbol
        // we've just created. Otherwise, add a membership constraint on the type of the symbol
        // itself, so as to handle implicit select exressions (i.e. Swift-like enum cases).
        if let owner = node.owner {
            try self.visit(owner)
            self.constraints.append(.belongs(node.ownee.symbol!, (owner as! TypedNode).type!))
        } else {
            self.constraints.append(.belongs(node.ownee.symbol!, node.type!))
        }
    }

    public mutating func visit(_ node: CallArg) throws {
        try self.visit(node.value)
        node.type = (node.value as! TypedNode).type
    }

    public mutating func visit(_ node: Ident) throws {
        // Create a fresh variable for the node.
        node.type = TypeVariable()

        // Retrieve the symbol(s) associated with the identifier and create a specialization
        // constraint for each one of them.
        let symbols = node.scope![node.name]
        assert(!symbols.isEmpty)
        self.constraints.append(.or(symbols.map({ Constraint.specializes(node.type!, $0.type) })))
    }

    public func visit(_ node: Literal<Int>) {
        node.type = Builtins.instance.Int
    }

    public func visit(_ node: Literal<Bool>) {
        node.type = Builtins.instance.Bool
    }

    public func visit(_ node: Literal<String>) {
        node.type = Builtins.instance.String
    }

    public var constraints: [Constraint] = []

}

// MARK: Internals

/// Returns the type denoted by a type annotation.
fileprivate func analyzeTypeAnnotation(_ node: Node) throws -> QualifiedType {
    switch node {
    case let qualifiedSignature as QualSign:
        return try! analyzeQualifiedSignature(qualifiedSignature)
    case _ as FunSign:
        fatalError("TODO")
    case let identifier as Ident:
        return try QualifiedType(type: analyzeIdentifier(identifier), qualifiedBy: [.cst])
    default:
        fatalError("unexpected node for type annotation")
    }
}

/// Returns the type denoted by a complete signature.
///
/// Qualified signature may or may not include an unqualified signature. We say the signature is
/// "complete" in the former case, and "incomplete" otherwise. For instance, the `@cst Int` is a
/// complete (qualified) signature, while `Int` is incomplete.
///
/// In the case of complete signature, this function uses the type identified by the unqualified
/// part of the signature. In the case of incomplete signatures, a fresh variable is created.
fileprivate func analyzeQualifiedSignature(_ node: QualSign) throws -> QualifiedType {
    // Make sure the signature isn't qualified by incompatible qualifiers.
    guard !node.qualifiers.contains(.cst) || !node.qualifiers.contains(.mut) else {
        throw InferenceError(reason: "incompatible qualifiers", location: node.location)
    }

    // Analyse the unqualified part of the signature.
    switch node.signature {
    case _ as FunSign:
        fatalError("TODO")
    case let identifier as Ident:
        return try QualifiedType(
            type: analyzeIdentifier(identifier), qualifiedBy: Set(node.qualifiers))
    default:
        fatalError("unexpected node for type annotation")
    }
}

/// Returns the type denoted by a type identifier.
fileprivate func analyzeIdentifier(_ node: Ident) throws -> SemanticType {
    // The symbol should be associated a type alias or type placeholder. Obviously, it shouldn't
    // be overloaded neither, as we can't type expressions with function names.
    let symbols = node.scope![node.name]
    assert(!symbols.isEmpty)

    switch symbols[0].type {
    case let alias as TypeAlias:
        node.type = alias
        return alias.type
    case let placeholder as TypePlaceholder:
        node.type = placeholder
        return placeholder
    default:
        throw InferenceError(reason: "'\(node.name)' is not a type", location: node.location)
    }
}
