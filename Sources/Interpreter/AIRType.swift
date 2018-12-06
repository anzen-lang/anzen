import AST

public class AIRType {

  fileprivate init() {}

  public static func == (lhs: AIRType, rhs: AIRType) -> Bool {
    return lhs === rhs
  }

  public static let anything  = AIRBuiltinType(name: "Anything")
  public static let nothing   = AIRBuiltinType(name: "Nothing")
  public static let bool      = AIRBuiltinType(name: "Bool")
  public static let int       = AIRBuiltinType(name: "Int")
  public static let float     = AIRBuiltinType(name: "Float")
  public static let string    = AIRBuiltinType(name: "String")

  public static func builtin(named name: String) -> AIRType? {
    return AIRType.builtinTypes[name]
  }

  /// Built-in AIR types.
  private static var builtinTypes: [String: AIRType] = [
    "Anything": .anything,
    "Nothing" : .nothing,
    "Bool"    : .bool,
    "Int"     : .int,
    "Float"   : .float,
    "String"  : .string,
    ]

}

public final class AIRBuiltinType: AIRType, CustomStringConvertible {

  fileprivate init(name: String) {
    self.name = name
  }

  public let name: String

  public var description: String {
    return self.name
  }

}

public final class AIRFunctionType: AIRType, CustomStringConvertible {

  public init(domain: [AIRType], codomain: AIRType) {
    self.domain = domain
    self.codomain = codomain
  }

  public let domain: [AIRType]
  public let codomain: AIRType

  public var description: String {
    return "(" + domain.map({ "\($0)" }).joined(separator: ",") + ") -> \(codomain)"
  }

}

public final class AIRStructType: AIRType, CustomStringConvertible {

  public init(name: String, elements: [AIRType]) {
    self.name = name
    self.elements = elements
  }

  public let name: String
  public var elements: [AIRType]

  public var description: String {
    return self.name
  }

}
