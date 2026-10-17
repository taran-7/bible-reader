import Foundation
import GRDB
import Testing
@testable import BibleCore

/// FR-42: visit history.
@MainActor @Suite struct VisitHistoryTests {
    static func entry(_ book: Int, _ chapter: Int, _ verse: Int? = 1, _ translation: Translation = .kjv) -> VisitEntry {
        VisitEntry(translation: translation, book: book, chapter: chapter, verse: verse)
    }

    func tempDatabaseURL() throws -> URL {
        try TestSupport.tempDirectory().appendingPathComponent("userdata.sqlite")
    }

    // @trace FR-42
    @Test func testRowIsTheBookAndReferenceInTheTranslationLanguage() {
        #expect(Self.entry(43, 3, 16, .kjv).title == "John 3:16")
        #expect(Self.entry(43, 3, 16, .synodal).title == "От Иоанна 3:16")
        #expect(Self.entry(43, 3, 16, .ohienko).title == "Від Івана 3:16")
        #expect(Self.entry(43, 3, 16, .popchenko).title == "Від Іоана 3:16")
        // A plain chapter open has no verse.
        #expect(Self.entry(43, 4, nil, .kjv).title == "John 4")
    }

    // @trace FR-42
    @Test func testNewestFirst() {
        let history = VisitHistory(database: nil)
        history.record(Self.entry(1, 1))
        history.record(Self.entry(43, 3, 16))
        history.record(Self.entry(19, 23, 1))
        #expect(history.entries.map(\.book) == [19, 43, 1])
    }

    // @trace FR-42
    @Test func testSameTranslationAndVerseMovesToTheTop() {
        let history = VisitHistory(database: nil)
        history.record(Self.entry(43, 3, 16))
        history.record(Self.entry(1, 1))
        history.record(Self.entry(43, 3, 16))
        #expect(history.entries.map(\.book) == [43, 1])
    }

    // @trace FR-42
    @Test func testTheSameVerseInAnotherTranslationIsAnotherEntry() {
        let history = VisitHistory(database: nil)
        history.record(Self.entry(43, 3, 16, .kjv))
        history.record(Self.entry(43, 3, 16, .ohienko))
        #expect(history.entries.map(\.translation) == [.ohienko, .kjv])
        // A chapter without a verse is not the verse either.
        history.record(Self.entry(43, 3, nil, .ohienko))
        #expect(history.entries.count == 3)
    }

    // @trace FR-42
    @Test func testLimitIs50AndTheOldestIsDropped() {
        let history = VisitHistory(database: nil)
        for verse in 1...51 { history.record(Self.entry(1, 1, verse)) }
        #expect(history.entries.count == 50)
        #expect(history.entries.first?.verse == 51)
        // The first visit is gone; what was 50th before the 51st visit is now the 50th from the second one.
        #expect(history.entries.last?.verse == 2)
        #expect(!history.entries.contains { $0.verse == 1 })
    }

    // @trace FR-42
    @Test func testRevisitingAtTheLimitDropsNothing() {
        let history = VisitHistory(database: nil)
        for verse in 1...50 { history.record(Self.entry(1, 1, verse)) }
        history.record(Self.entry(1, 1, 1))
        #expect(history.entries.count == 50)
        #expect(history.entries.first?.verse == 1)
        #expect(history.entries.last?.verse == 2)
    }

    // @trace FR-42
    @Test func testSurvivesARestart() throws {
        let url = try tempDatabaseURL()
        let history = VisitHistory(database: try UserDatabase(path: url))
        history.record(Self.entry(1, 1, 1, .kjv))
        history.record(Self.entry(43, 3, 16, .ohienko))
        history.record(Self.entry(43, 4, nil, .synodal))
        let reopened = VisitHistory(database: try UserDatabase(path: url))
        #expect(reopened.entries == history.entries)
        #expect(reopened.entries.map(\.verse) == [nil, 16, 1])
    }

    // @trace FR-42
    @Test func testLimitAndDedupeArePersisted() throws {
        let url = try tempDatabaseURL()
        let history = VisitHistory(database: try UserDatabase(path: url))
        for verse in 1...55 { history.record(Self.entry(1, 1, verse)) }
        history.record(Self.entry(1, 1, 10))
        let reopened = VisitHistory(database: try UserDatabase(path: url))
        #expect(reopened.entries.count == 50)
        #expect(reopened.entries.first?.verse == 10)
        #expect(reopened.entries.filter { $0.verse == 10 }.count == 1)
        #expect(reopened.entries == history.entries)
    }

    // @trace FR-42
    @Test func testClearHistory() throws {
        let url = try tempDatabaseURL()
        let history = VisitHistory(database: try UserDatabase(path: url))
        history.record(Self.entry(1, 1))
        history.clear()
        #expect(history.entries.isEmpty)
        #expect(VisitHistory(database: try UserDatabase(path: url)).entries.isEmpty)
    }

    // @trace FR-42
    @Test func testRowsOfAnUnknownTranslationAreDropped() throws {
        let url = try tempDatabaseURL()
        let database = try UserDatabase(path: url)
        let history = VisitHistory(database: database)
        history.record(Self.entry(43, 3, 16, .kjv))
        try database.queue.write {
            try $0.execute(sql: "INSERT INTO visit (translation, book, chapter, verse) VALUES ('gone', 1, 1, 1)")
        }
        #expect(VisitHistory(database: database).entries.map(\.translation) == [.kjv])
    }
}

@MainActor @Suite struct VisitHistoryReaderTests {
    let repository = FakeRepository()

    func makeModel(history: VisitHistory? = VisitHistory(database: nil)) -> ReaderViewModel {
        ReaderViewModel(visitHistory: history) { self.repository }
    }

    // @trace FR-42
    @Test func testAJumpToAVerseIsRecorded() {
        let model = makeModel()
        model.query = "Ин 3:16"
        model.submitSearch()
        #expect(model.historyEntries == [VisitEntry(translation: .kjv, book: 43, chapter: 3, verse: 16)])
    }

    // @trace FR-42
    @Test func testAPlainChapterOpenIsRecordedWithoutAVerse() {
        let model = makeModel()
        model.open(Location(book: 43, chapter: 2), focus: 16)
        model.goNext()
        #expect(model.historyEntries.map(\.verse) == [nil, 16])
        #expect(model.historyEntries.first?.chapter == 3)
    }

    // @trace FR-42
    @Test func testSelectingAVerseIsRecordedInTheOnScreenTranslation() {
        let model = makeModel()
        model.translation = .synodal
        model.open(Location(book: 43, chapter: 3))
        model.anchorVerse = 5
        #expect(model.historyEntries.first == VisitEntry(translation: .synodal, book: 43, chapter: 3, verse: 5))
        // Clearing the selection records nothing.
        model.anchorVerse = nil
        #expect(model.historyEntries.count == 2)
    }

    // @trace FR-42
    @Test func testFocusEchoAfterAJumpDoesNotDuplicate() {
        let model = makeModel()
        model.open(Location(book: 43, chapter: 3), focus: 16)
        // The chapter view selects the focused verse, which sets the anchor verse.
        model.anchorVerse = 16
        #expect(model.historyEntries.count == 1)
    }

    // @trace FR-42
    @Test func testTheAppStartDoesNotRecordTheRestoredChapter() {
        #expect(makeModel().historyEntries.isEmpty)
    }

    // @trace FR-42
    @Test func testOpeningAnEntryUsesItsTranslation() {
        let model = makeModel()
        model.translation = .kjv
        model.openVisit(VisitEntry(translation: .ohienko, book: 43, chapter: 3, verse: 16))
        #expect(model.translation == .ohienko)
        #expect(model.location == Location(book: 43, chapter: 3))
        #expect(model.focusedVerse == 16)
        #expect(model.verses.first?.translation == .ohienko)
        // The number is not remapped: the entry is already in that translation's numbering.
        #expect(model.takeFocus() == 16)
    }

    // @trace FR-42
    @Test func testOpeningAChapterEntryDoesNotFocusAVerse() {
        let model = makeModel()
        model.openVisit(VisitEntry(translation: .kjv, book: 43, chapter: 2, verse: nil))
        #expect(model.location == Location(book: 43, chapter: 2))
        #expect(model.focusedVerse == nil)
    }

    // @trace FR-42
    @Test func testOpeningAnEntryClosesSearchResults() {
        let model = makeModel()
        model.query = "love"
        model.submitSearch()
        model.openVisit(VisitEntry(translation: .kjv, book: 1, chapter: 2, verse: 3))
        #expect(model.results == nil)
    }

    // @trace FR-42
    @Test func testCompareKeepsItsModeOnClick() {
        let model = makeModel()
        model.open(Location(book: 1, chapter: 1))
        model.showComparison(of: [1], with: [.synodal, .ohienko])
        model.openVisit(VisitEntry(translation: .ohienko, book: 43, chapter: 3, verse: 16))
        let comparison = try? #require(model.comparison)
        #expect(comparison?.location == Location(book: 43, chapter: 3))
        #expect(comparison?.highlighted == [16])
        // The entry's translation is the main (first) column; the earlier columns stay.
        #expect(comparison?.translations.first == .ohienko)
        #expect(Set(comparison?.translations ?? []) == [.ohienko, .kjv, .synodal])
    }

    // @trace FR-42
    @Test func testReadingStaysReadingOnClick() {
        let model = makeModel()
        model.openVisit(VisitEntry(translation: .kjv, book: 2, chapter: 1, verse: 1))
        #expect(model.comparison == nil)
    }

    // @trace FR-42
    @Test func testParallelViewKeepsItsModeOnClick() {
        let model = makeModel()
        // Same numbering, so the fake repository needs no mapping table.
        model.parallelTranslation = .kjv
        model.openVisit(VisitEntry(translation: .ohienko, book: 43, chapter: 3, verse: 16))
        #expect(model.parallelTranslation == .kjv)
        #expect(model.parallelRows.first?.primary.translation == .ohienko)
        #expect(model.parallelRows.first?.secondary.first?.translation == .kjv)
    }

    // @trace FR-42
    @Test func testEntriesOfAnUnavailableTranslationAreHiddenAndDoNotOpen() {
        let history = VisitHistory(database: nil)
        let model = ReaderViewModel(visitHistory: history) { NewTestamentRepository(hasPopchenko: false) }
        history.record(VisitEntry(translation: .popchenko, book: 43, chapter: 3, verse: 16))
        history.record(VisitEntry(translation: .kjv, book: 43, chapter: 3, verse: 16))
        #expect(model.historyEntries.map(\.translation) == [.kjv])
        model.openVisit(VisitEntry(translation: .popchenko, book: 43, chapter: 3, verse: 16))
        #expect(model.translation == .kjv)
    }

    // @trace FR-42
    @Test func testClearHistory() {
        let model = makeModel()
        model.open(Location(book: 1, chapter: 2), focus: 3)
        model.clearHistory()
        #expect(model.historyEntries.isEmpty)
    }

    // @trace FR-42
    @Test func testWithoutAHistoryNothingBreaks() {
        let model = makeModel(history: nil)
        model.open(Location(book: 1, chapter: 2), focus: 3)
        #expect(model.historyEntries.isEmpty)
    }
}
