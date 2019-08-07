/// An Type transformer that "opens" generic types, effectively substituting occurrences of generic
/// placeholders with fresh variables.
public class TypeOpener: TypeTransformer {

  public typealias Result = TypeBase

  /// The compiler context.
  public let context: CompilerContext
  /// The bindings that have been used to open generic parameters.
  private var bindings: [TypePlaceholder: TypeVar] = [:]

  public init(bindings: [TypePlaceholder: TypeVar], context: CompilerContext) {
    self.context = context
  }

  /// Opens a type kind.
  ///
  /// Opening a type kind consists in opening the type it constructs.
  public func transform(_ ty: TypeKind) -> TypeBase {
    return context.getTypeKind(of: ty.type.accept(transformer: self))
  }

  /// Opens a type variable.
  ///
  /// Opening a type variable corresponds to the identity.
  public func transform(_ ty: TypeVar) -> TypeBase {
    return ty
  }

  /// Opens a type placeholder.
  ///
  /// Opening a type placeholder either returns the type variable that's been chosen as a
  /// substitution, or corresponds to the identity if such substitution hasn't been defined.
  public func transform(_ ty: TypePlaceholder) -> TypeBase {
    return bindings[ty] ?? ty
  }

  /// Opens a bound generic type.
  ///
  /// Opening a bound generic type consists in merging the new substitutions.
  public func transform(_ ty: BoundGenericType) -> TypeBase {
    let newBindings = ty.bindings.merging(bindings) { lhs, _ in lhs }
    return context.getBoundGenericType(type: ty, bindings: newBindings)
  }

  /// Opens a function type.
  ///
  /// Opening a function type creates a substitution for each of its generic argument, so that the
  /// type can be monomorphized.
  public func transform(_ ty: FunType) -> TypeBase {
    guard !ty.genericParams.isEmpty
      else { return ty }

    var newBindings = bindings
    for param in ty.genericParams where bindings[param] == nil {
      newBindings[param] = context.getTypeVar()
    }
    let newOpener = TypeOpener(bindings: newBindings, context: context)

    return context.getFunType(
      quals: ty.quals,
      genericParams: [],
      dom: ty.dom.map({
        FunType.Param(label: $0.label, type: $0.type.accept(transformer: newOpener))
      }),
      codom: ty.codom.accept(transformer: newOpener))
  }

  /// Opens an interface type.
  ///
  /// Opening an interface type creates a substitution for each of its generic argument, so that
  /// the type can be monomorphized.
  public func transform(_ ty: InterfaceType) -> TypeBase {
    guard !ty.decl.genericParams.isEmpty
      else { return ty }

    var newBindings = bindings
    for param in ty.genericParams where bindings[param] == nil {
      newBindings[param] = context.getTypeVar()
    }

    return context.getBoundGenericType(type: ty, bindings: newBindings)
  }

  /// Opens a struct type.
  ///
  /// Opening a struct type creates a substitution for each of its generic argument, so that the
  /// type can be monomorphized.
  public func transform(_ ty: StructType) -> TypeBase {
    guard !ty.decl.genericParams.isEmpty
      else { return ty }

    var newBindings = bindings
    for param in ty.genericParams where bindings[param] == nil {
      newBindings[param] = context.getTypeVar()
    }

    return context.getBoundGenericType(type: ty, bindings: newBindings)
  }

  /// Opens a union type.
  ///
  /// Opening a union type creates a substitution for each of its generic argument, so that the
  /// type can be monomorphized.
  public func transform(_ ty: UnionType) -> TypeBase {
    guard !ty.decl.genericParams.isEmpty
      else { return ty }

    var newBindings = bindings
    for param in ty.genericParams where bindings[param] == nil {
      newBindings[param] = context.getTypeVar()
    }

    return context.getBoundGenericType(type: ty, bindings: newBindings)
  }

  public func transform(_ ty: BuiltinType) -> TypeBase {
    return ty
  }

  public func transform(_ ty: ErrorType) -> TypeBase {
    return ty
  }

}
