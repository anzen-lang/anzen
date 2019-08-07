/// An type transformor.
///
/// Conform to this protocol to implement an type transformer.
public protocol TypeTransformer {

  associatedtype Result

  func transform(_ ty: TypeKind) -> Result
  func transform(_ ty: TypeVar) -> Result
  func transform(_ ty: TypePlaceholder) -> Result
  func transform(_ ty: BoundGenericType) -> Result
  func transform(_ ty: FunType) -> Result
  func transform(_ ty: InterfaceType) -> Result
  func transform(_ ty: StructType) -> Result
  func transform(_ ty: UnionType) -> Result

}
