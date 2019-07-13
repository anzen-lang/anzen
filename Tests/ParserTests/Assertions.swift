import XCTest

func assertThat<Subject>(
  file: StaticString = #file,
  line: UInt = #line,
  _ subject: Subject,
  _ check: (Subject) -> Bool) {
  XCTAssert(check(subject), file: file, line: line)
}

func assertThat<Subject>(
  file: StaticString = #file,
  line: UInt = #line,
  _ subject: Subject,
  _ assertion: Assertion<Subject>) {
  XCTAssert(assertion.check(for: subject), file: file, line: line)
}

struct Assertion<Subject> {

  private let predicate: (Subject) -> Bool

  init(_ predicate: @escaping (Subject) -> Bool) {
    self.predicate = predicate
  }

  func check(for subject: Subject) -> Bool {
    return predicate(subject)
  }

  static func not(_ assertion: Assertion<Subject>) -> Assertion<Subject> {
    return Assertion { !assertion.check(for: $0) }
  }

  static func isInstance<T>(of type: T.Type) -> Assertion<Subject> {
    return Assertion { $0 is T }
  }

}

protocol OptionalConvertible {

  associatedtype Wrapped

  var optional: Wrapped? { get }

}

extension Optional: OptionalConvertible {

  var optional: Wrapped? { return self }

}

extension Assertion where Subject: OptionalConvertible {

  static var isNil: Assertion<Subject> {
    return Assertion { $0.optional == nil }
  }

}

extension Assertion where Subject: Equatable {

  static func equals(_ other: Subject) -> Assertion<Subject> {
    return Assertion { $0 == other }
  }

}

extension Assertion where Subject: Collection {

  static var isEmpty: Assertion<Subject> {
    return Assertion { $0.isEmpty }
  }

  static func count(_ n: Int) -> Assertion<Subject> {
    return Assertion { $0.count == n }
  }

}

extension Assertion where Subject: Collection, Subject.Element: Equatable {

  static func contains(_ element: Subject.Element) -> Assertion<Subject> {
    return Assertion { $0.contains(element) }
  }

}
