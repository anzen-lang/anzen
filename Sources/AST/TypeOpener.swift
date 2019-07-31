/// An Type transformer that "opens" generic types, effectively substituting occurrences of generic
/// placeholders with fresh variables.
public class TypeOpener: TypeWalker {

  public typealias Result = TypeBase

  /// The compiler context.
  public let context: CompilerContext
  /// The bindings that have been used to open generic parameters.
  private var bindings: [TypePlaceholder: TypeVar] = [:]

  public init(bindings: [TypePlaceholder: TypeVar], context: CompilerContext) {
    self.context = context
  }

  public func walk(_ ty: TypeKind) -> TypeBase {
    return context.getTypeKind(of: walk(ty.type))
  }

  public func walk(_ ty: TypeVar) -> TypeBase {
    return ty
  }

  public func walk(_ ty: TypePlaceholder) -> TypeBase {
    return bindings[ty] ?? ty
  }

  public func walk(_ ty: BoundGenericType) -> TypeBase {
    let newBindings = ty.bindings.merging(bindings) { lhs, _ in lhs }
    return context.getBoundGenericType(type: ty, bindings: newBindings)
  }

  public func walk(_ ty: FunType) -> TypeBase {
    guard !ty.genericParams.isEmpty else { return ty }

    var newBindings = bindings
    for param in ty.genericParams where bindings[param] == nil {
      newBindings[param] = context.getTypeVar()
    }
    let newOpener = TypeOpener(bindings: newBindings, context: context)

    return context.getFunType(
      quals: ty.quals,
      genericParams: [],
      dom: ty.dom.map({ FunType.Param(label: $0.label, type: newOpener.walk($0.type)) }),
      codom: newOpener.walk(ty.codom))
  }

  public func walk(_ ty: StructType) -> TypeBase {
    guard !ty.decl.genericParams.isEmpty else { return ty }

    var newBindings = bindings
    for param in ty.genericParams where bindings[param] == nil {
      newBindings[param] = context.getTypeVar()
    }

    return context.getBoundGenericType(type: ty, bindings: newBindings)
  }

  public func walk(_ ty: UnionType) -> TypeBase {
    guard !ty.decl.genericParams.isEmpty else { return ty }

    var newBindings = bindings
    for param in ty.genericParams where bindings[param] == nil {
      newBindings[param] = context.getTypeVar()
    }

    return context.getBoundGenericType(type: ty, bindings: newBindings)
  }

}
