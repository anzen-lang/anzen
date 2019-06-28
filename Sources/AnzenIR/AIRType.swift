import AST
import Utils

public class AIRType: Equatable {

  fileprivate init() {}

  /// The metatype of the type.
  public lazy var metatype: AIRMetatype = { [unowned self] in
    return AIRMetatype(of: self)
  }()

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

public final class AIRMetatype: AIRType, CustomStringConvertible {

  fileprivate init(of type: AIRType) {
    self.type = type
  }

  public let type: AIRType

  public var description: String {
    return "\(type).metatype"
  }

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

  internal init(domain: [AIRType], codomain: AIRType) {
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

  internal init(name: String, members: OrderedMap<String, AIRType>) {
    self.name = name
    self.members = members
  }

  public let name: String
  public var members: OrderedMap<String, AIRType>

  public var description: String {
    return self.name
  }

}
