/// A type walker implementing the visitor pattern.
public protocol TypeWalker {

  associatedtype Result

  func walk(_ ty: TypeKind) -> Result
  func walk(_ ty: TypeVar) -> Result
  func walk(_ ty: TypePlaceholder) -> Result
  func walk(_ ty: BoundGenericType) -> Result
  func walk(_ ty: FunType) -> Result
  func walk(_ ty: StructType) -> Result
  func walk(_ ty: UnionType) -> Result

}

extension TypeWalker {

  public func walk(_ ty: TypeBase) -> Result {
    switch ty {
    case let t as TypeKind: return walk(t)
    case let t as TypeVar: return walk(t)
    case let t as TypePlaceholder: return walk(t)
    case let t as BoundGenericType: return walk(t)
    case let t as FunType: return walk(t)
    case let t as StructType: return walk(t)
    case let t as UnionType: return walk(t)
    default:
      fatalError("unexpected type class \(type(of: ty))")
    }
  }

}
