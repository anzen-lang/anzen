import XCTest

/// Asserts that a statement is true.
///
/// This function is inspired by the assertion mechanism proposed in JUnit, which proposes to write
/// assertions with the following syntax:
///
///     assertThat(subject, statement)
///
/// The advantage of this approach over the more classic `XCTAssert` family of functions is that
/// using the above arguably yields more readable statements.
///
/// `subject` can be any Swift value, and `statement` any predicate on `subject`. For instance, the
/// following assertion holds.
///
///     assertThat(3) { $0 > 1 }
///
/// For the sake of legibility, an overloaded version of `assertThat` accepts a special `Assertion`
/// object in place of the predicate, which can act as a functor.
public func assertThat<Subject>(
  file: StaticString = #file,
  line: UInt = #line,
  _ subject: Subject,
  _ check: (Subject) -> Bool) {
  XCTAssert(check(subject), file: file, line: line)
}

/// Asserts that a statement is true, using an assertion functor.
public func assertThat<Subject>(
  file: StaticString = #file,
  line: UInt = #line,
  _ subject: Subject,
  _ assertion: Assertion<Subject>) {
  XCTAssert(assertion.check(for: subject), file: file, line: line)
}

public struct Assertion<Subject> {

  private let predicate: (Subject) -> Bool

  public init(_ predicate: @escaping (Subject) -> Bool) {
    self.predicate = predicate
  }

  public func check(for subject: Subject) -> Bool {
    return predicate(subject)
  }

  public static func not(_ assertion: Assertion<Subject>) -> Assertion<Subject> {
    return Assertion { !assertion.check(for: $0) }
  }

  public static func isInstance<T>(of type: T.Type) -> Assertion<Subject> {
    return Assertion { $0 is T }
  }

}

extension Assertion where Subject: OptionalConvertible {

  public static var isNil: Assertion<Subject> {
    return Assertion { $0.optional == nil }
  }

}

extension Assertion where Subject: Equatable {

  public static func equals(_ other: Subject) -> Assertion<Subject> {
    return Assertion { $0 == other }
  }

}

extension Assertion where Subject: Collection {

  public static var isEmpty: Assertion<Subject> {
    return Assertion { $0.isEmpty }
  }

  public static func count(_ n: Int) -> Assertion<Subject> {
    return Assertion { $0.count == n }
  }

  public static func contains(elementSuchThat predicate: @escaping (Subject.Element) -> Bool)
    -> Assertion<Subject>
  {
    return Assertion { $0.contains(where: predicate) }
  }

}

extension Assertion where Subject: Collection, Subject.Element: Equatable {

  public static func contains(_ element: Subject.Element) -> Assertion<Subject> {
    return Assertion { $0.contains(element) }
  }

}
