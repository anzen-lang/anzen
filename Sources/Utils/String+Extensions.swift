extension StringProtocol {

  public func firstRange<S>(of substring: S) -> ClosedRange<Self.Index>? where S: StringProtocol {
    var i = startIndex
    while index(i, offsetBy: substring.count - 1) < endIndex {
      let range = i ... index(i, offsetBy: substring.count - 1)
      if self[range] == substring {
        return range
      } else {
        i = index(after: i)
      }
    }
    return nil
  }

  public func replacing(_ substring: String, with replacement: String) -> String {
    var result = String(self)
    while let range = result.firstRange(of: substring) {
      result.removeSubrange(range)
      result.insert(contentsOf: replacement, at: range.lowerBound)
    }
    return result
  }

}
