extension StringProtocol {

  public func range(of substring: Self) -> Range<Self.Index>? {
    var i = startIndex
    while i < endIndex {
      if self[i] == substring[substring.startIndex] {
        let j = index(i, offsetBy: substring.count)
        if self[i ..< j] == substring {
          return i ..< j
        }
      }
      i = index(after: i)
    }

    return nil
  }

  public func replacing(_ substring: String, with replacement: String) -> String {
    var result = String(self)
    while let r = result.range(of: substring) {
      result =
        String(result[result.startIndex ..< r.lowerBound]) +
        String(result[r.upperBound ..< result.endIndex])
    }
    return result
  }

}
