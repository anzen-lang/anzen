import AST
import Utils

/// This represents an AIR function.
public class AIRFunction: AIRValue {

  internal init(name: String, type: FunctionType) {
    self.name = name
    self.type = type
  }

  public let type: TypeBase
  public let name: String?

  public private(set) var blocks: OrderedMap<String, InstructionBlock> = [:]

  @discardableResult
  public func appendBlock(name: String) -> InstructionBlock {
    assert(blocks[name] == nil)

    let ib = InstructionBlock(function: self)
    blocks[name] = ib
    return ib
  }

  public var valueDescription: String {
    return "$\(name!)"
  }

}

extension AIRFunction: Hashable {

  public var hashValue: Int {
    return name!.hashValue
  }

  public static func == (lhs: AIRFunction, rhs: AIRFunction) -> Bool {
    return lhs === rhs
  }

}

/// This represents a formal parameter of a function.
///
/// A formal parameter does not contain any actual value, but instead represents the argument that
/// will be passed to the function, when it is called.
public struct AIRParameter: AIRValue {

  public let type: TypeBase
  public let name: String

  public var valueDescription: String {
    return "%\(name)"
  }

}
