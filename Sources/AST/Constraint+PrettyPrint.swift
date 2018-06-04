// FIXME: This should be in the "diagnostic" target.

import Utils

extension Constraint {

  public func prettyPrint(in console: Console = Console.err, level: Int = 0) {
    let ident = String(repeating: " ", count: level * 2)
    console.print(
      ident + location.anchor.range.start.description.styled("< 6") + ": ",
      terminator: "")

    switch kind {
    case .equality:
      console.print("\(types!.t) ≡ \(types!.u)".styled("bold"))
    case .conformance:
      console.print("\(types!.t) ≤ \(types!.u)".styled("bold"))
    case .member:
      console.print("\(types!.t).\(member!) ≡ \(types!.u)".styled("bold"))
    case .disjunction:
      console.print("")
      for constraint in choices {
        constraint.prettyPrint(in: console, level: level + 1)
      }
    }
  }

}
