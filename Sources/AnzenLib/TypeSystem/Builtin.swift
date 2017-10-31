public final class BuiltinScope: Scope {

    public init() {
        super.init(name: "Anzen")

        self.add(symbol: Symbol(
            name: "Type",
            type: self.makeTypeName(from: BuiltinScope.AnzenType)))
        self.add(symbol: Symbol(
            name: "Nothing",
            type: self.makeTypeName(from: BuiltinScope.AnzenNothing)))
        self.add(symbol: Symbol(
            name: "Int",
            type: self.makeTypeName(from: BuiltinScope.AnzenInt)))
        self.add(symbol: Symbol(
            name: "Bool",
            type: self.makeTypeName(from: BuiltinScope.AnzenBool)))
        self.add(symbol: Symbol(
            name: "String",
            type: self.makeTypeName(from: BuiltinScope.AnzenString)))
    }

    // MARK: Builtin types

    public static var AnzenType    = TypeFactory.makeStruct(name: "Type")
    public static var AnzenNothing = TypeFactory.makeStruct(name: "Nothing")

    public static var AnzenInt     = TypeFactory.makeStruct(name: "Int")
    public static var AnzenBool    = TypeFactory.makeStruct(name: "Bool")
    public static var AnzenString  = TypeFactory.makeStruct(name: "String")

    // MARK: Internals

    private func makeTypeName(from builtinType: StructType) -> QualifiedType {
        return QualifiedType(
            type: TypeFactory.makeName(name: builtinType.name, type: builtinType),
            qualifiedBy: [])
    }

}
