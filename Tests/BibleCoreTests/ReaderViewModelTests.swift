import Testing
@testable import BibleCore

/// Кожна книга має 3 розділи по 5 віршів; пошук повертає Ин 3:16 для будь-якого запиту.
final class FakeRepository: BibleRepository, @unchecked Sendable {
    var searches: [String] = []

    func books(translation: Translation) throws -> [Book] { Book.all }
    func chapterCount(book: Int, translation: Translation) throws -> Int { 3 }
    func verses(book: Int, chapter: Int, translation: Translation) throws -> [Verse] {
        (1...5).map { Verse(translation: translation, book: book, chapter: chapter, verse: $0, text: "\(translation.rawValue) \(book):\(chapter):\($0)") }
    }
    func search(_ query: String, translation: Translation, limit: Int) throws -> [SearchResult] {
        searches.append(query)
        guard query != "nothing" else { return [] }
        let verse = Verse(translation: translation, book: 43, chapter: 3, verse: 16, text: "found")
        return [SearchResult(verse: verse, segments: [.init(text: "found", isMatch: true)])]
    }
}

@MainActor @Suite struct ReaderViewModelTests {
    let repository = FakeRepository()

    func makeModel() -> ReaderViewModel {
        ReaderViewModel { self.repository }
    }

    @Test func testStartsAtGenesis1() {
        let model = makeModel()
        #expect(model.location == Location(book: 1, chapter: 1))
        #expect(model.verses.count == 5)
        #expect(model.books.count == 66)
        #expect(!model.canGoPrevious)
        #expect(model.canGoNext)
    }

    @Test func testSwitchTranslationKeepsPlace() {
        let model = makeModel()
        model.open(Location(book: 43, chapter: 3))
        model.translation = .synodal
        #expect(model.location == Location(book: 43, chapter: 3))
        #expect(model.verses.first?.translation == .synodal)
    }

    @Test func testNextCrossesBook() {
        let model = makeModel()
        model.open(Location(book: 1, chapter: 3))
        model.goNext()
        #expect(model.location == Location(book: 2, chapter: 1))
        model.goPrevious()
        #expect(model.location == Location(book: 1, chapter: 3))
    }

    @Test func testReferenceQueryNavigates() {
        let model = makeModel()
        model.query = "Ин 3:16"
        model.submitSearch()
        #expect(model.location == Location(book: 43, chapter: 3))
        #expect(model.focusedVerse == 16)
        #expect(repository.searches.isEmpty)
        #expect(model.results == nil)
    }

    @Test func testTextQuerySearches() {
        let model = makeModel()
        model.query = "love"
        model.submitSearch()
        #expect(repository.searches == ["love"])
        #expect(model.results?.count == 1)
    }

    @Test func testNothingFound() {
        let model = makeModel()
        model.query = "nothing"
        model.submitSearch()
        #expect(model.results?.isEmpty == true)
    }

    @Test func testSubmittedQueryIsKeptWhileTyping() {
        let model = makeModel()
        model.query = "nothing"
        model.submitSearch()
        model.query = "love"
        #expect(model.submittedQuery == "nothing")
    }

    @Test func testClearingQueryHidesResults() {
        let model = makeModel()
        model.query = "love"
        model.submitSearch()
        model.query = ""
        model.submitSearch()
        #expect(model.results == nil)
    }

    @Test func testOpenResult() throws {
        let model = makeModel()
        model.query = "love"
        model.submitSearch()
        model.open(try #require(model.results?.first))
        #expect(model.location == Location(book: 43, chapter: 3))
        #expect(model.focusedVerse == 16)
        #expect(model.results == nil)
    }

    @Test func testCopySelection() {
        let model = makeModel()
        model.translation = .synodal
        model.open(Location(book: 43, chapter: 3))
        #expect(model.quote(for: [3, 2]) == "«synodal 43:3:2 synodal 43:3:3» (От Иоанна 3:2-3)")
        #expect(model.quote(for: []) == nil)
    }

    @Test func testDatabaseError() {
        struct Boom: Error {}
        let model = ReaderViewModel { throw Boom() }
        #expect(model.loadError != nil)
        #expect(model.verses.isEmpty)
    }
}
