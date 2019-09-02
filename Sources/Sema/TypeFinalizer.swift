import AST

final class TypeFinalizer: TypeTransformer {

  typealias Result = TypeBase

  /// The compiler context.
  let context: CompilerContext

  /// The type substitutions.
  let substitutions: [TypeVar: TypeBase]

  init(context: CompilerContext, substitutions: [TypeVar: TypeBase]) {
    self.context = context
    self.substitutions = substitutions
  }

  func finalize(type: QualType) -> QualType {
    let bareType = type.bareType.accept(transformer: self)
    let quals = type.quals.isEmpty
      ? [.cst]
      : type.quals
    return QualType(bareType: bareType, quals: quals)
  }

  func transform(_ ty: TypeKind) -> TypeBase {
    guard ty.info.check(TypeInfo.hasTypeVar)
      else { return ty }
    return ty.type.accept(transformer: self).kind
  }

  func transform(_ ty: TypeVar) -> TypeBase {
    if let replacement = substitutions[ty] {
      return replacement.accept(transformer: self)
    } else {
      return ty
    }
  }

  func transform(_ ty: TypePlaceholder) -> TypeBase {
    return ty
  }

  func transform(_ ty: BoundGenericType) -> TypeBase {
    let bindings = ty.bindings.mapValues(finalize)
    return context.getBoundGenericType(
      type: ty.type.accept(transformer: self),
      bindings: bindings)
  }

  func transform(_ ty: FunType) -> TypeBase {
    let dom = ty.dom.map { param -> FunType.Param in
      let paramTy = self.finalize(type: param.type)
      return FunType.Param(label: param.label, type: paramTy)
    }
    let codom = finalize(type: ty.codom)
    return context.getFunType(placeholders: ty.placeholders, dom: dom, codom: codom)
  }

  func transform(_ ty: InterfaceType) -> TypeBase {
    return ty
  }

  func transform(_ ty: StructType) -> TypeBase {
    return ty
  }

  func transform(_ ty: UnionType) -> TypeBase {
    return ty
  }

  func transform(_ ty: BuiltinType) -> TypeBase {
    return ty
  }

  func transform(_ ty: ErrorType) -> TypeBase {
    return ty
  }

}
