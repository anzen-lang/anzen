import AST
import Utils

/// This represents an AIR function.
public class AIRFunction: AIRValue {

  internal init(name: String, type: AIRFunctionType) {
    self.name = name
    self.type = type
  }

  public let type: AIRType
  public let name: String

  /// The instruction blocks of the function.
  public private(set) var blocks: OrderedMap<String, InstructionBlock> = [:]
  /// The ID of the next unnamed virtual register.
  private var _nextRegisterID = 1

  @discardableResult
  public func appendBlock(label: String) -> InstructionBlock {
    let uniqueLabel = uniquify(label)
    assert(blocks[uniqueLabel] == nil)

    let ib = InstructionBlock(label: uniqueLabel, function: self)
    blocks[label] = ib
    return ib
  }

  public func nextRegisterID() -> Int {
    defer { _nextRegisterID += 1 }
    return _nextRegisterID
  }

  public var valueDescription: String {
    return "$\(name)"
  }

  private func uniquify(_ label: String) -> String {
    if blocks[label] == nil {
      return label
    }
    let greatestID = blocks.compactMap({
      $0.key.starts(with: label)
        ? Int($0.key.dropFirst(label.count)) ?? 0
        : nil
    }).max() ?? 0
    return "\(label)\(greatestID + 1)"
  }

}

extension AIRFunction: Hashable {

  public func hash(into hasher: inout Hasher) {
    hasher.combine(name)
  }

  public static func == (lhs: AIRFunction, rhs: AIRFunction) -> Bool {
    return lhs === rhs
  }

}

/// This represents a formal parameter of a function.
///
/// A formal parameter does not contain any actual value, but instead represents the argument that
/// will be passed to the function, when it is called.
public struct AIRParameter: AIRRegister {

  public let type: AIRType
  public let id: Int

  public var valueDescription: String {
    return "%\(id)"
  }

}

