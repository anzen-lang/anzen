import AST
import Utils

/// This represents an AIR function.
public class AIRFunction: AIRValue {

  /// The type of the funciton.
  public let type: AIRType
  /// The (mangled) name of the function.
  public let name: String
  /// The debug information associated with this function.
  public var debugInfo: DebugInfo?

  /// The instruction blocks of the function.
  public private(set) var blocks: OrderedMap<String, InstructionBlock> = [:]
  /// The occurences of each label.
  private var labelOccurences: [String: Int] = [:]
  /// The ID of the next unnamed virtual register.
  private var _nextRegisterID = 1

  internal init(name: String, type: AIRFunctionType, debugInfo: DebugInfo? = nil) {
    self.name = name
    self.type = type
    self.debugInfo = debugInfo
  }

  @discardableResult
  public func appendBlock(label: String) -> InstructionBlock {
    let uniqueLabel = uniquify(label)
    assert(blocks[uniqueLabel] == nil)

    let ib = InstructionBlock(label: uniqueLabel, function: self)
    blocks[uniqueLabel] = ib
    return ib
  }

  @discardableResult
  public func insertBlock(after block: InstructionBlock, label: String) -> InstructionBlock {
    let uniqueLabel = uniquify(label)
    assert(blocks[uniqueLabel] == nil)

    let ib = InstructionBlock(label: uniqueLabel, function: self)
    let index = blocks.index(of: block.label)
    precondition(index != nil, "no block labeled '\(block.label)'")
    blocks.insert(ib, forKey: uniqueLabel, at: index! + 1)
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
    assert(!label.contains("#"))
    let occ = labelOccurences[label] ?? 0
    labelOccurences[label] = occ + 1
    return "\(label)#\(occ)"
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
  public let debugInfo: DebugInfo?

  public var valueDescription: String {
    return "%\(id)"
  }

}
