/// A type transformer that reifies generic types, effectively substituting occurences of type
/// variables with concrete types.
public class TypeReifier {

  public typealias Result = TypeBase

  /// The compiler context.
  public let context: CompilerContext
  /// The bindings that have been used to open generic parameters.
  private var bindings: [TypePlaceholder: TypeVar] = [:]

  public init(bindings: [TypePlaceholder: TypeVar], context: CompilerContext) {
    self.context = context
  }

}
