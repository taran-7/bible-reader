import Foundation
import Testing
@testable import BibleCore

@MainActor @Suite struct ParallelTests {
    func makeModel() -> ReaderViewModel {
        ReaderViewModel { try SQLiteBibleRepository(path: TestSupport.realDatabase) }
    }

    // @trace FR-27
    @Test func testSwitchingTranslationKeepsTheVerse() {
        let model = makeModel()
        model.open(Location(book: 19, chapter: 22))
        model.anchorVerse = 1
        model.translation = .synodal
        #expect(model.location == Location(book: 19, chapter: 21))
        #expect(model.takeFocus() == 2)
        model.anchorVerse = 2
        model.translation = .ohienko
        #expect(model.location == Location(book: 19, chapter: 22))
        #expect(model.takeFocus() == 1)
        // Without a selection: the first verse of the chapter, no focus.
        model.anchorVerse = nil
        model.translation = .synodal
        #expect(model.location == Location(book: 19, chapter: 21))
        #expect(model.takeFocus() == nil)
        // A chapter without a counterpart (Ps 151) stays in place.
        model.open(Location(book: 19, chapter: 151))
        model.translation = .kjv
        #expect(model.location == Location(book: 19, chapter: 150))
    }

    // @trace FR-27
    @Test func testSameNumberingSwitchKeepsChapter() {
        let model = makeModel()
        model.open(Location(book: 19, chapter: 23))
        model.anchorVerse = 4
        model.translation = .bkr
        #expect(model.location == Location(book: 19, chapter: 23))
        #expect(model.takeFocus() == 4)
    }

    // @trace FR-26
    @Test func testParallelRowsAlignByVerse() throws {
        let model = makeModel()
        model.open(Location(book: 19, chapter: 22))
        model.parallelTranslation = .synodal
        let rows = model.parallelRows
        #expect(rows.count == model.verses.count)
        // KJV Ps 22:1 next to the superscription and Synodal Ps 21:2.
        #expect(rows[0].primary.verse == 1)
        #expect(rows[0].secondary.map(\.verse) == [1, 2])
        #expect(rows[0].secondary.map(\.chapter) == [21, 21])
        #expect(rows[1].secondary.map(\.verse) == [3])
        // The same numbering: verse for verse.
        model.parallelTranslation = .ohienko
        #expect(model.parallelRows.allSatisfy { $0.secondary.map(\.verse) == [$0.primary.verse] })
        model.parallelTranslation = nil
        #expect(model.parallelRows.isEmpty)
    }

    // @trace FR-26
    @Test func testParallelAcrossChapterBoundaryAndMerges() {
        let model = makeModel()
        // KJV Jonah 1:17 = Synodal Jonah 2:1.
        model.open(Location(book: 32, chapter: 1))
        model.parallelTranslation = .synodal
        #expect(model.parallelRows.last?.secondary.map { "\($0.chapter):\($0.verse)" } == ["2:1"])
        // KJV Acts 19:40–41 is one verse 19:40: it stands next to the first, the second row is empty.
        model.open(Location(book: 44, chapter: 19))
        let rows = model.parallelRows
        #expect(rows[39].secondary.map(\.verse) == [40])
        #expect(rows[40].secondary.isEmpty)
        // The Synodal as the main one: additions (Dan 3:24–90) are separate rows, unpaired ones are not lost.
        model.translation = .synodal
        model.open(Location(book: 27, chapter: 3))
        model.parallelTranslation = .kjv
        #expect(model.parallelRows.count == 100)
        #expect(model.parallelRows[30].secondary.isEmpty)
        #expect(model.parallelRows[90].secondary.map { "\($0.chapter):\($0.verse)" } == ["3:24"])
    }

    // @trace FR-26
    @Test func testParallelPersistsInPreferences() throws {
        var preferences = ReadingPreferences()
        #expect(preferences.parallelTranslation == nil)
        preferences.parallelTranslation = .synodal
        let decoded = try JSONDecoder().decode(ReadingPreferences.self, from: JSONEncoder().encode(preferences))
        #expect(decoded.parallelTranslation == .synodal)
    }
}

extension ParallelTests {
    // @trace FR-27
    @Test func testUserDataUsesKJVNumbering() {
        let model = makeModel()
        model.translation = .synodal
        model.open(Location(book: 19, chapter: 21))
        // Synodal Ps 21:2 is KJV Ps 22:1; the superscription (21:1) also leads to 22:1.
        #expect(model.canonicalKey(2) == VerseKey(book: 19, chapter: 22, verse: 1))
        #expect(model.canonicalChapter == Bookmark.Target(book: 19, chapter: 22, verse: nil))
        #expect(model.localReference(book: 19, chapter: 22, verse: 1).format(in: .synodal) == "Пс. 21:2")
        // KJV Ps 23 without a superscription verse: Synodal Ps 22:1.
        model.openCanonical(book: 19, chapter: 23, verse: 1)
        #expect(model.location == Location(book: 19, chapter: 22))
        #expect(model.takeFocus() == 1)
        model.openNote(VerseKey(book: 19, chapter: 22, verse: 1))
        #expect(model.location == Location(book: 19, chapter: 21))
        // Septuagint additions without a counterpart keep their own number.
        model.open(Location(book: 27, chapter: 3))
        #expect(model.canonicalKey(30) == VerseKey(book: 27, chapter: 3, verse: 30))
    }

    // @trace FR-24
    @Test func testMarksForSingleVerse() throws {
        let data = UserData(database: try UserDatabase.inMemory())
        let key = VerseKey(book: 19, chapter: 22, verse: 1)
        data.setNote("n", for: key)
        data.toggleBookmark(.init(book: 19, chapter: 22, verse: 1))
        data.setHighlight(.blue, for: [key])
        #expect(data.marks(for: key) == VerseMarks(highlight: .blue, hasNote: true, isBookmarked: true))
        #expect(data.marks(for: VerseKey(book: 1, chapter: 1, verse: 1)) == VerseMarks())
    }
}

extension ParallelTests {
    // @trace FR-27
    @Test func testRemapFallsBackToPreviousMappedVerseAndMergedMarks() throws {
        let model = makeModel()
        // Synodal Dan 3:50 (the song of the three youths) → KJV Dan 3:23, the last verse with a counterpart before it.
        model.translation = .synodal
        model.open(Location(book: 27, chapter: 3))
        model.anchorVerse = 50
        model.translation = .kjv
        #expect(model.location == Location(book: 27, chapter: 3))
        #expect(model.takeFocus() == 23)
        // Synodal Lev 14:55 = KJV 14:55–56: the marks of both.
        model.translation = .synodal
        model.open(Location(book: 3, chapter: 14))
        #expect(model.canonicalKeys(55) == [VerseKey(book: 3, chapter: 14, verse: 55), VerseKey(book: 3, chapter: 14, verse: 56)])
        let data = UserData(database: try UserDatabase.inMemory())
        data.setNote("n", for: VerseKey(book: 3, chapter: 14, verse: 56))
        #expect(data.marks(for: model.canonicalKeys(55)).hasNote)
        // A chapter bookmark on Synodal Num 13 is KJV Num 13, although the first verse is KJV 12:16.
        model.open(Location(book: 4, chapter: 13))
        #expect(model.canonicalChapter == Bookmark.Target(book: 4, chapter: 13, verse: nil))
        model.translation = .kjv
        #expect(model.canonicalKeys(1) == [model.canonicalKey(1)])
    }
}

/// The second translation cannot be read: the parallel column is empty, not an error for the whole chapter.
final class FailingSecondRepository: BibleRepository, @unchecked Sendable {
    let base = FakeRepository()
    func books(translation: Translation) throws -> [Book] { try base.books(translation: translation) }
    func chapterCount(book: Int, translation: Translation) throws -> Int { 3 }
    func verses(book: Int, chapter: Int, translation: Translation) throws -> [Verse] {
        if translation == .ohienko { throw FakeRepository.Boom() }
        return try base.verses(book: book, chapter: chapter, translation: translation)
    }
    func searchPage(_ query: String, translation: Translation, scope: SearchScope, offset: Int, limit: Int) throws -> SearchPage { .empty }
}

extension ParallelTests {
    // @trace FR-26
    @Test func testUnreadableSecondTranslationGivesEmptyColumn() {
        let model = ReaderViewModel { FailingSecondRepository() }
        model.parallelTranslation = .ohienko
        #expect(model.parallelRows.count == 5)
        #expect(model.parallelRows.allSatisfy { $0.secondary.isEmpty })
        let broken = ReaderViewModel { throw FakeRepository.Boom() }
        #expect(broken.canonicalChapter.chapter == 1)
    }
}
