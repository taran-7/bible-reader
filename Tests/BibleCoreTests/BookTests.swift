import Testing
@testable import BibleCore

@Suite struct BookTests {
    // @trace FR-5
    @Test func testSixtySixBooks() {
        #expect(Book.all.count == 66)
        #expect(Book.all.map(\.number) == Array(1...66))
        #expect(Book(number: 43)?.name(in: .kjv) == "John")
        #expect(Book(number: 67) == nil)
    }

    // @trace FR-5
    @Test func testRussianNames() {
        #expect(Book(number: 1)?.name(in: .synodal) == "Бытие")
        #expect(Book(number: 40)?.name(in: .synodal) == "От Матфея")
        #expect(Book(number: 43)?.abbreviation(in: .synodal) == "Ин")
        #expect(Book(number: 46)?.abbreviation(in: .synodal) == "1 Кор")
    }

    // @trace FR-5
    @Test func testTestamentSplit() {
        #expect(Book.all.filter { $0.testament == .old }.count == 39)
        #expect(Book.all.filter { $0.testament == .new }.count == 27)
        #expect(Book(number: 40)?.testament == .new)
    }
}
