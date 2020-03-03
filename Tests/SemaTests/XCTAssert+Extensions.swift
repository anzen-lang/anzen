import XCTest

import SystemKit

func XCTAssertLinesEqual(_ lhs: String, _ rhs: String, path: Path) {
  let lhsLines = lhs.split(separator: "\n")
  let rhsLines = rhs.split(separator: "\n")

  var errors: [(lineno: Int, lhs: String, rhs: String)] = []
  for (i, (ll, rl)) in zip(lhsLines, rhsLines).enumerated() where ll != rl {
    errors.append((lineno: i + 1, lhs: String(ll), rhs: String(rl)))
  }

  guard errors.isEmpty else {
    XCTFail("\(path.filename!)")
    for (lineno, ll, rl) in errors {
      print("  L\(lineno) | expected: " + ll.trimmingCharacters(in: [" "]).styled("green"))
      print("  L\(lineno) | obtained: " + rl.trimmingCharacters(in: [" "]).styled("red"))
    }
    return
  }

  guard lhsLines.count == rhsLines.count else {
    XCTFail("\(path.filename!): different line count")
    return
  }
}
