import Testing
@testable import BibleCore

/// Кожна книга має 3 розділи по 5 віршів; пошук повертає Ин 3:16 для будь-якого запиту.
final class FakeRepository: BibleRepository, @unchecked Sendable {
    var searches: [String] = []
    var limits: [Int] = []
    var offsets: [Int] = []
    var scopes: [SearchScope] = []
    var chapterCountCalls = 0
    /// Разова помилка читання віршів (tech debt #11).
    var failNextVerses = false
    struct Boom: Error {}

    func books(translation: Translation) throws -> [Book] { Book.all }
    func chapterCount(book: Int, translation: Translation) throws -> Int {
        chapterCountCalls += 1
        return 3
    }
    func verses(book: Int, chapter: Int, translation: Translation) throws -> [Verse] {
        if failNextVerses {
            failNextVerses = false
            throw Boom()
        }
        return (1...5).map { Verse(translation: translation, book: book, chapter: chapter, verse: $0, text: "\(translation.rawValue) \(book):\(chapter):\($0)") }
    }
    /// «many» дає 250 збігів (вірші 1…250 Буття 1), інше — один Ин 3:16.
    func searchPage(_ query: String, translation: Translation, scope: SearchScope, offset: Int, limit: Int) throws -> SearchPage {
        searches.append(query)
        limits.append(limit)
        offsets.append(offset)
        scopes.append(scope)
        if query == "boom" || (query == "boom later" && offset > 0) { throw Boom() }
        guard query != "nothing" else { return .empty }
        if query == "shrinking" {
            // База «змінилась»: обіцяно 150, а друга сторінка порожня.
            return offset == 0 ? SearchPage(results: Array(repeating: SearchResult(
                verse: Verse(translation: translation, book: 1, chapter: 1, verse: 1, text: "x"), segments: []), count: 100), total: 150) : .empty
        }
        if query == "boom later" {
            return SearchPage(results: [SearchResult(verse: Verse(translation: translation, book: 1, chapter: 1, verse: 1, text: "x"), segments: [])], total: 5)
        }
        if query == "many" {
            let results = (offset..<min(offset + limit, 250)).map { index in
                SearchResult(verse: Verse(translation: translation, book: 1, chapter: 1, verse: index + 1, text: "many"),
                             segments: [.init(text: "many", isMatch: true)])
            }
            return SearchPage(results: results, total: 250)
        }
        let verse = Verse(translation: translation, book: 43, chapter: 3, verse: 16, text: "found")
        return SearchPage(results: [SearchResult(verse: verse, segments: [.init(text: "found", isMatch: true)])], total: 1)
    }
}

@MainActor @Suite struct ReaderViewModelTests {
    let repository = FakeRepository()

    func makeModel() -> ReaderViewModel {
        ReaderViewModel { self.repository }
    }

    // @trace FR-6
    @Test func testStartsAtGenesis1() {
        let model = makeModel()
        #expect(model.location == Location(book: 1, chapter: 1))
        #expect(model.verses.count == 5)
        #expect(model.books.count == 66)
        #expect(!model.canGoPrevious)
        #expect(model.canGoNext)
    }

    // @trace FR-4
    @Test func testSwitchTranslationKeepsPlace() {
        let model = makeModel()
        model.open(Location(book: 43, chapter: 3))
        model.translation = .synodal
        #expect(model.location == Location(book: 43, chapter: 3))
        #expect(model.verses.first?.translation == .synodal)
    }

    // @trace FR-6
    @Test func testNextCrossesBook() {
        let model = makeModel()
        model.open(Location(book: 1, chapter: 3))
        model.goNext()
        #expect(model.location == Location(book: 2, chapter: 1))
        model.goPrevious()
        #expect(model.location == Location(book: 1, chapter: 3))
    }

    // @trace FR-13
    @Test func testReferenceQueryNavigates() {
        let model = makeModel()
        model.query = "Ин 3:16"
        model.submitSearch()
        #expect(model.location == Location(book: 43, chapter: 3))
        #expect(model.focusedVerse == 16)
        #expect(repository.searches.isEmpty)
        #expect(model.results == nil)
    }

    // @trace FR-11
    @Test func testTextQuerySearches() {
        let model = makeModel()
        model.query = "love"
        model.submitSearch()
        #expect(repository.searches == ["love"])
        #expect(model.results?.count == 1)
    }

    // @trace FR-11
    @Test func testNothingFound() {
        let model = makeModel()
        model.query = "nothing"
        model.submitSearch()
        #expect(model.results?.isEmpty == true)
    }

    // @trace FR-11
    @Test func testSubmittedQueryIsKeptWhileTyping() {
        let model = makeModel()
        model.query = "nothing"
        model.submitSearch()
        model.query = "love"
        #expect(model.submittedQuery == "nothing")
    }

    // @trace FR-11
    @Test func testClearingQueryHidesResults() {
        let model = makeModel()
        model.query = "love"
        model.submitSearch()
        model.query = ""
        model.submitSearch()
        #expect(model.results == nil)
        #expect(!model.canLoadMore)
    }

    // @trace FR-14
    @Test func testOpenResult() throws {
        let model = makeModel()
        model.query = "love"
        model.submitSearch()
        model.open(try #require(model.results?.first))
        #expect(model.location == Location(book: 43, chapter: 3))
        #expect(model.focusedVerse == 16)
        #expect(model.results == nil)
    }

    // @trace FR-10
    @Test func testCopySelection() {
        let model = makeModel()
        model.translation = .synodal
        model.open(Location(book: 43, chapter: 3))
        #expect(model.quote(for: [3, 2]) == "«2 synodal 43:3:2\n3 synodal 43:3:3»\n(От Иоанна 3:2-3)")
        #expect(model.quote(for: []) == nil)
    }

    // @trace FR-7
    @Test func testDatabaseError() {
        struct Boom: Error {}
        let model = ReaderViewModel { throw Boom() }
        #expect(model.loadError != nil)
        #expect(!model.canRetryLoad)
        #expect(model.verses.isEmpty)
    }

    // @trace FR-7
    @Test func testTransientReadErrorClearsOnNextSuccessfulLoad() {
        let model = makeModel()
        repository.failNextVerses = true
        model.goNext()
        #expect(model.loadError != nil)
        #expect(model.canRetryLoad)
        model.retryLoad()
        #expect(model.loadError == nil)
        #expect(model.location == Location(book: 1, chapter: 2))
        #expect(model.verses.count == 5)
    }

    // @trace FR-8
    @Test func testChapterPastBookEndOpensLastChapter() {
        let model = makeModel()
        model.query = "John 99"
        model.submitSearch()
        #expect(model.location == Location(book: 43, chapter: 3))
    }

    // @trace FR-6
    @Test func testPrevNextCloseSearchResults() {
        let model = makeModel()
        model.query = "love"
        model.submitSearch()
        #expect(model.results != nil)
        model.goNext()
        #expect(model.results == nil)
        model.query = "boom"
        model.submitSearch()
        #expect(model.searchError != nil)
        model.goPrevious()
        #expect(model.searchError == nil)
    }

    // @trace FR-6
    @Test func testCanGoDoesNotQueryDatabaseOnEveryRead() {
        let model = makeModel()
        let before = repository.chapterCountCalls
        for _ in 0..<10 {
            _ = model.canGoPrevious
            _ = model.canGoNext
        }
        #expect(repository.chapterCountCalls == before)
    }

    // @trace FR-13
    @Test func testSameVerseNumberInAnotherBookRefocuses() {
        let model = makeModel()
        model.query = "Ин 3:16"
        model.submitSearch()
        let first = model.focusRequest
        model.query = "Рим 3:16"
        model.submitSearch()
        #expect(model.focusedVerse == 16)
        #expect(model.focusRequest != first)
    }

    // @trace FR-13
    @Test func testSameReferenceAgainRefocuses() {
        let model = makeModel()
        model.query = "Ин 3:16"
        model.submitSearch()
        let first = model.focusRequest
        model.submitSearch()
        #expect(model.focusRequest != first)
    }

    // @trace FR-11
    @Test func testTranslationSwitchRerunsSubmittedQuery() {
        let model = makeModel()
        model.query = "love"
        model.submitSearch()
        model.query = "John 3"
        model.translation = .synodal
        #expect(repository.searches.last == "love")
        #expect(model.results != nil)
        #expect(model.location == Location(book: 1, chapter: 1))
    }

    // @trace FR-20
    @Test func testResultsArePagedWithTotal() {
        let model = makeModel()
        model.query = "many"
        model.submitSearch()
        #expect(model.results?.count == ReaderViewModel.pageSize)
        #expect(model.resultTotal == 250)
        #expect(model.canLoadMore)
        model.loadMore()
        model.loadMore()
        #expect(repository.offsets == [0, 100, 200])
        #expect(model.results?.count == 250)
        #expect(model.results?.map(\.verse.verse) == Array(1...250))
        #expect(!model.canLoadMore)
        model.loadMore()
        #expect(repository.offsets == [0, 100, 200])
    }

    // @trace FR-19
    @Test func testScopeChangeRerunsSearch() {
        let model = makeModel()
        #expect(model.searchScope == .bible)
        model.searchScope = .newTestament
        #expect(repository.searches.isEmpty)
        model.query = "love"
        model.submitSearch()
        #expect(repository.scopes == [.newTestament])
        model.searchScope = .book(43)
        #expect(repository.scopes == [.newTestament, .book(43)])
        #expect(repository.offsets == [0, 0])
        model.searchScope = .book(43)
        #expect(repository.scopes.count == 2)
    }

    // @trace FR-19
    @Test func testCurrentBookScopeFollowsLocation() {
        let model = makeModel()
        #expect(model.currentBookScope == .book(1))
        model.open(Location(book: 43, chapter: 1))
        #expect(model.currentBookScope == .book(43))
        // Обрана книга лишається в панелі, навіть коли відкрили іншу.
        model.searchScope = .book(43)
        model.open(Location(book: 1, chapter: 1))
        #expect(model.currentBookScope == .book(43))
    }

    // @trace FR-20
    @Test func testLoadMoreStopsOnEmptyPageAndReportsErrors() {
        let model = makeModel()
        model.query = "shrinking"
        model.submitSearch()
        model.loadMore()
        #expect(model.resultTotal == 100)
        #expect(!model.canLoadMore)
        model.query = "boom later"
        model.submitSearch()
        model.loadMore()
        // Помилка сторінки не ховає вже знайдене.
        #expect(model.pageError != nil)
        #expect(model.searchError == nil)
        #expect(model.results?.count == 1)
        model.submitSearch()
        #expect(model.pageError == nil)
    }

    // @trace FR-19
    @Test func testNoRepositoryIgnoresPaging() {
        let model = ReaderViewModel { throw FakeRepository.Boom() }
        model.loadMore()
        model.searchScope = .newTestament
        model.query = "love"
        model.submitSearch()
        #expect(model.results == nil)
    }

    // @trace FR-12
    @Test func testSearchErrorIsNotNothingFound() {
        let model = makeModel()
        model.query = "boom"
        model.submitSearch()
        #expect(model.searchError != nil)
        #expect(model.results == nil)
        model.query = "love"
        model.submitSearch()
        #expect(model.searchError == nil)
    }
}

extension ReaderViewModelTests {
    // @trace FR-13
    @Test func testFocusIsTakenOncePerRequest() {
        let model = makeModel()
        model.query = "Ин 3:16"
        model.submitSearch()
        #expect(model.takeFocus() == 16)
        // Повторне відображення розділу (напр. після очищення пошуку) не забирає фокус знову.
        #expect(model.takeFocus() == nil)
        model.submitSearch()
        #expect(model.takeFocus() == 16)
    }
}

extension ReaderViewModelTests {
    // @trace FR-24
    @Test func testOpenNoteClosesResultsAndFocusesVerse() {
        let model = makeModel()
        model.query = "love"
        model.submitSearch()
        model.openNote(VerseKey(book: 19, chapter: 2, verse: 1))
        #expect(model.results == nil)
        #expect(model.location == Location(book: 19, chapter: 2))
        #expect(model.takeFocus() == 1)
    }

    // @trace FR-17
    @Test func testClearSelectionOnlyWithoutSidePanels() {
        let model = ReaderViewModel { FakeRepository() }
        #expect(!model.canClearSelection)
        model.anchorVerse = 2
        #expect(model.canClearSelection)
        model.showIllustrations(for: [2])
        #expect(!model.canClearSelection || model.illustrations == nil)
        model.closeIllustrations()
        model.clearSelection()
        #expect(model.clearSelectionRequest == 1)
    }
}
