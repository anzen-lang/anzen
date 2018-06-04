/// A syled string.
///
/// Styled string is a small utility struct that can perform various substring substitutions for
/// styling and formatting purposes. It comes with a handful of styles, but also allows custom
/// styles to be added as well and can even override built-in styles.
///
/// To identify styled substrings, wrap them inside curly brackets, and specify the styles to be
/// applied after a colon, separated by a comma. For instance:
///
///    let message: StyledString = "This message is {very:body,red} important."
///
/// Some styles may require parameters. Those should be specified after the name of the style,
/// separated by a space. For instance:
///
///    let message: StyledString = "This message is {very:rgb 67 115 50} green."
///
/// Note that styles are applied in order, which may be of importance when applying styles that
/// expect the subject to be parsed in a certain way (e.g. `round`).
public struct StyledString: CustomStringConvertible, ExpressibleByStringLiteral {

  public init(_ value: String) throws {
    var styled = ""
    styled.reserveCapacity(value.count)

    var cursor = value.startIndex
    var isParsingExpression = false
    var expression: String = ""

    while cursor != value.endIndex {
      let token = value[cursor]
      cursor = value.index(after: cursor)

      switch token {
      case "{":
        // Escape pairs of `{`.
        guard (cursor == value.endIndex) || (value[cursor] != "{") else {
          cursor = value.index(after: cursor)
          if isParsingExpression {
            expression.append("{")
          } else {
            styled.append("{")
          }
          continue
        }

        isParsingExpression = true

      case "}":
        // Escape pairs of `}`.
        guard (cursor == value.endIndex) || (value[cursor] != "}") else {
          cursor = value.index(after: cursor)
          if isParsingExpression {
            expression.append("}")
          } else {
            styled.append("}")
          }
          continue
        }

        var subject = ""

        var i = expression.startIndex
        while let end = expression.suffix(from: i).index(of: ":") {
          subject += String(expression[i ..< end])

          let next = expression.index(after: end)
          guard next != expression.endIndex else {
            styled.append(expression)
            break
          }
          guard expression[next] != ":" else {
            subject += ":"
            i = expression.index(after: next)
            continue
          }

          // let subject = String(expression[expression.startIndex ..< end])
          let styles = String(expression[next ..< expression.endIndex])
          try styled.append(StyledString.format(subject: subject, styles: styles))
          break
        }

        isParsingExpression = false
        expression = ""

      default:
        if isParsingExpression {
          expression.append(token)
        } else {
          styled.append(token)
        }
      }
    }

    self.value = styled
  }

  public init(stringLiteral value: String) {
    try! self.init(value)
  }

  private var value: String

  public var description: String {
    return value
  }

  /// This dictionary keeps track of the styles `StyledString` is capable of applying. It may be
  /// mutated to add and/or override the available styles.
  public static var styles: [String: Style] = [
    "<"        : PadLeft(),
    ">"        : PadRight(),
    "bold"     : AnsiSRG(code: 1),
    "dimmed"   : AnsiSRG(code: 2),
    "italic"   : AnsiSRG(code: 3),
    "underline": AnsiSRG(code: 4),
    "blink"    : AnsiSRG(code: 5),
    "reversed" : AnsiSRG(code: 7),
    "strike"   : AnsiSRG(code: 9),
    "black"    : AnsiSRG(code: 30),
    "red"      : AnsiSRG(code: 31),
    "green"    : AnsiSRG(code: 32),
    "yellow"   : AnsiSRG(code: 33),
    "blue"     : AnsiSRG(code: 34),
    "magenta"  : AnsiSRG(code: 35),
    "cyan"     : AnsiSRG(code: 36),
    "white"    : AnsiSRG(code: 37),
    "default"  : AnsiSRG(code: 39),
    "bgblack"  : AnsiSRG(code: 40),
    "bgred"    : AnsiSRG(code: 41),
    "bggreen"  : AnsiSRG(code: 42),
    "bgyellow" : AnsiSRG(code: 43),
    "bgblue"   : AnsiSRG(code: 44),
    "bgmagenta": AnsiSRG(code: 45),
    "bgcyan"   : AnsiSRG(code: 46),
    "bgwhite"  : AnsiSRG(code: 47),
    "bgdefault": AnsiSRG(code: 49),
    "rgb"      : AnsiRGB(),
    "round"    : Round(),
  ]

  public static func format(subject: String, styles: String) throws -> String {
    let styles = styles
      .split(separator: ",")
      .map({ $0.stripped.split(separator: " ") })
      .filter({ !$0.isEmpty })

    var result = subject
    for components in styles {
      guard let style = StyledString.styles[String(components[0])]
        else { throw StyleError(message: "unknown style '\(components[0])'") }
      result = try style.apply(on: result, parameters: Array(components.dropFirst()))
    }

    return result
  }

}

extension StyledString: BidirectionalCollection {

  public typealias Element = String.Element
  public typealias Index = String.Index

  public var startIndex: Index { return value.startIndex }
  public var endIndex: Index { return value.endIndex }

  public func index(after i: Index) -> Index {
    return value.index(after: i)
  }

  public func index(before i: Index) -> Index {
    return value.index(before: i)
  }

  public subscript(position: Index) -> Element {
    return value[position]
  }

}

extension String {

  public func styled(_ styles: String) -> String {
    return try! StyledString.format(subject: self, styles: styles)
  }

}

// MARK: Styles

/// The protocol styles should conform to.
///
/// This protocol can be used to create custom styles. It defines a method `apply` that should
/// accept the subject string to be styled, as well as the optional parameters, and return the
/// transformed string to substitute.
public protocol Style {

  /// Applies this style to the given subject.
  func apply(on subject: String, parameters: [Substring]) throws -> String

}

public struct StyleError: Error {

  public init(message: String) {
    self.message = message
  }

  public let message: String

}

/// Aligns a text to the left.
///
/// - Usage: `{text:< w c}` where `w` is the minimum width of the text and `c` an optional the
///   padding character.
public struct PadLeft: Style {

  public func apply(on subject: String, parameters: [Substring]) throws -> String {
    guard parameters.count > 0
      else { throw StyleError(message: "< requires at least 1 argument") }
    guard let width = Int(parameters[0])
      else { throw StyleError(message: "cannot convert '\(parameters[0])' to Int") }
    let pad = parameters.count > 1
      ? String(parameters[1])
      : " "
    return width > subject.count
      ? String(subject) + String(repeating: pad, count: width - subject.count)
      : String(subject)
  }

}

/// Aligns a text to the right.
///
/// - Usage: `{text:> w c}` where `w` is the minimum width of the text and `c` an optional the
///   padding character.
public struct PadRight: Style {

  public func apply(on subject: String, parameters: [Substring]) throws -> String {
    guard parameters.count > 0
      else { throw StyleError(message: "< requires at least 1 argument") }
    guard let width = Int(parameters[0])
      else { throw StyleError(message: "cannot convert '\(parameters[0])' to Int") }
    let pad = parameters.count > 1
      ? String(parameters[1])
      : " "
    return width > subject.count
      ? String(repeating: pad, count: width - subject.count) + String(subject)
      : String(subject)
  }

}

/// Applies a SRG ANSI escape sequence to the text. The styled string is expected to be displayed
/// in a compatible terminal.
public struct AnsiSRG: Style {

  public func apply(on subject: String, parameters: [Substring]) -> String {
    return "\u{001B}[\(code)m\(subject)\u{001B}[0m"
  }

  public let code: UInt32

}

/// Applies a SRG ANSI escape sequence for the RGB color palette to the text. The styled string is
/// expected to be displayed in a compatbile terminal.
///
/// - Usage: `{text:rgb r g b}` where `r`, `g` and `b` are values in the range 0 ..< 255.
public struct AnsiRGB: Style {

  public func apply(on subject: String, parameters: [Substring]) throws -> String {
    guard parameters.count == 3
      else { throw StyleError(message: "rgb requires 3 arguments") }
    let values = try parameters.map { (s) -> Int in
      guard let v = Int(s)
        else { throw StyleError(message: "cannot convert '\(s)' to Int") }
      guard 0 ..< 256 ~= v
        else { throw StyleError(message: "value '\(v)' is outside of range") }
      return Int((Double(v) * 5.0 / 255.0).rounded())
    }
    let rgb = 16 + 36 * values[0] + 6 * values[1] + values[2]
    return "\u{001B}[38;5;\(rgb)m\(subject)\u{001B}[0m"
  }

}

/// Rounds a floating-point value to a specified number of decimals.
public struct Round: Style {

  public func apply(on subject: String, parameters: [Substring]) throws -> String {
    guard parameters.count == 1
      else { throw StyleError(message: "round requires 1 argument") }
    guard let digits = Int(parameters[0])
      else { throw StyleError(message: "cannot convert '\(parameters[0])' to Int") }
    guard let value = Double(subject)
      else { throw StyleError(message: "cannot convert '\(subject)' to Double") }

    let multiplier: Double = (0 ..< digits).reduce(1, { result, _ in result * 10 })
    return String(describing: (value * multiplier).rounded() / multiplier)
  }

}

// MARK: Helpers

extension String {

  fileprivate func head(while predicate: (String.Index) throws -> Bool) rethrows -> Substring {
    var i = startIndex
    while try predicate(i) {
      i = index(after: i)
    }
    return self[startIndex ..< i]
  }

}

extension String.SubSequence {

  fileprivate var stripped: Substring {
    let result = drop(while: { $0 == " " })
    var i = result.index(before: endIndex)
    while (i != result.startIndex) && (result[i] == " ") {
      i = result.index(before: i)
    }
    return result[result.startIndex ... i]
  }

}
