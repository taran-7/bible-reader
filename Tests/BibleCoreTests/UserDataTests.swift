import Foundation
import Testing
@testable import BibleCore

@MainActor @Suite struct UserDataTests {
    let john316 = VerseKey(book: 43, chapter: 3, verse: 16)
    let clock = Date(timeIntervalSince1970: 1_800_000_000)

    func makeData(at url: URL? = nil) throws -> UserData {
        UserData(database: try url.map(UserDatabase.init(path:)) ?? UserDatabase.inMemory(), now: { self.clock })
    }

    // @trace FR-22
    @Test func testVerseAndChapterBookmarks() throws {
        let data = try makeData()
        data.toggleBookmark(Bookmark.Target(book: 43, chapter: 3, verse: 16))
        data.toggleBookmark(Bookmark.Target(book: 1, chapter: 1, verse: nil))
        #expect(data.isBookmarked(Bookmark.Target(book: 43, chapter: 3, verse: 16)))
        #expect(data.isBookmarked(Bookmark.Target(book: 1, chapter: 1, verse: nil)))
        #expect(!data.isBookmarked(Bookmark.Target(book: 1, chapter: 1, verse: 1)))
        // Список у порядку книг.
        #expect(data.bookmarks.map(\.target) == [
            Bookmark.Target(book: 1, chapter: 1, verse: nil), Bookmark.Target(book: 43, chapter: 3, verse: 16),
        ])
        data.toggleBookmark(Bookmark.Target(book: 43, chapter: 3, verse: 16))
        #expect(data.bookmarks.count == 1)
    }

    // @trace FR-23
    @Test func testHighlightColors() throws {
        let data = try makeData()
        #expect(HighlightColor.allCases.count >= 3)
        data.setHighlight(.yellow, for: [john316, VerseKey(book: 43, chapter: 3, verse: 17)])
        #expect(data.highlight(for: john316) == .yellow)
        data.setHighlight(.green, for: [john316])
        #expect(data.highlight(for: john316) == .green)
        data.setHighlight(nil, for: [john316])
        #expect(data.highlight(for: john316) == nil)
        #expect(data.highlight(for: VerseKey(book: 43, chapter: 3, verse: 17)) == .yellow)
    }

    // @trace FR-24
    @Test func testNotesAndSearch() throws {
        let data = try makeData()
        data.setNote("Центральний вірш Євангелія", for: john316)
        data.setNote("Про СТВОРЕННЯ світу", for: VerseKey(book: 1, chapter: 1, verse: 1))
        #expect(data.note(for: john316)?.text == "Центральний вірш Євангелія")
        #expect(data.searchNotes("створення").map(\.key) == [VerseKey(book: 1, chapter: 1, verse: 1)])
        #expect(data.searchNotes("вірш").map(\.key) == [john316])
        #expect(data.searchNotes("  ").isEmpty)
        // Порожній текст видаляє нотатку.
        data.setNote("  \n", for: john316)
        #expect(data.note(for: john316) == nil)
        #expect(data.notes.count == 1)
    }

    // @trace FR-22
    // @trace FR-24
    @Test func testSurvivesReopen() throws {
        let dir = try TestSupport.tempDirectory()
        let url = dir.appendingPathComponent("userdata.sqlite")
        do {
            let data = try makeData(at: url)
            data.toggleBookmark(Bookmark.Target(book: 43, chapter: 3, verse: 16))
            data.setHighlight(.blue, for: [john316])
            data.setNote("нотатка", for: john316)
        }
        let reopened = try makeData(at: url)
        #expect(reopened.bookmarks.count == 1)
        #expect(reopened.highlight(for: john316) == .blue)
        #expect(reopened.note(for: john316)?.text == "нотатка")
    }

    // @trace FR-24
    @Test func testChapterMarks() throws {
        let data = try makeData()
        data.setNote("n", for: john316)
        data.setHighlight(.pink, for: [VerseKey(book: 43, chapter: 3, verse: 1)])
        data.toggleBookmark(Bookmark.Target(book: 43, chapter: 3, verse: 2))
        let marks = data.marks(book: 43, chapter: 3)
        #expect(marks[16]?.hasNote == true)
        #expect(marks[1]?.highlight == .pink)
        #expect(marks[2]?.isBookmarked == true)
        #expect(marks[5] == nil)
        #expect(data.marks(book: 43, chapter: 4).isEmpty)
    }

    // @trace FR-24
    @Test func testExportJSONAndMarkdown() throws {
        let data = try makeData()
        data.toggleBookmark(Bookmark.Target(book: 43, chapter: 3, verse: nil))
        data.setHighlight(.yellow, for: [john316])
        data.setNote("Любов Бога", for: john316)
        let json = try data.exportJSON()
        let decoded = try JSONDecoder.userData.decode(UserDataExport.self, from: json)
        #expect(decoded.bookmarks.map(\.target) == [Bookmark.Target(book: 43, chapter: 3, verse: nil)])
        #expect(decoded.highlights == [.init(key: john316, color: .yellow)])
        #expect(decoded.notes.map(\.text) == ["Любов Бога"])
        let markdown = data.exportMarkdown(in: .kjv)
        #expect(markdown.contains("## Закладки"))
        #expect(markdown.contains("- John 3"))
        #expect(markdown.contains("### John 3:16"))
        #expect(markdown.contains("Любов Бога"))
        #expect(markdown.contains("- John 3:16 — жовтий"))
    }

    // @trace FR-22
    @Test func testBrokenDatabaseThrows() throws {
        let dir = try TestSupport.tempDirectory()
        let url = dir.appendingPathComponent("userdata.sqlite")
        try Data("not a database".utf8).write(to: url)
        #expect(throws: (any Error).self) { try UserDatabase(path: url) }
    }
}

@MainActor @Suite struct LastPositionTests {
    // @trace FR-25
    @Test func testReopensAtLastPlace() {
        let storage = DictionaryStore()
        let repository = FakeRepository()
        let model = ReaderViewModel(positionStore: storage) { repository }
        model.translation = .synodal
        model.open(Location(book: 43, chapter: 3))
        let reopened = ReaderViewModel(positionStore: storage) { repository }
        #expect(reopened.translation == .synodal)
        #expect(reopened.location == Location(book: 43, chapter: 3))
    }

    // @trace FR-25
    @Test func testBrokenOrMissingPositionStartsAtGenesis() {
        let storage = DictionaryStore()
        storage.set(Data("{".utf8), forKey: ReaderViewModel.positionKey)
        let model = ReaderViewModel(positionStore: storage) { FakeRepository() }
        #expect(model.location == Location(book: 1, chapter: 1))
        #expect(model.translation == .kjv)
    }

    // @trace FR-25
    @Test func testPositionOutsideTheBibleIsClamped() throws {
        let storage = DictionaryStore()
        storage.set(Data(#"{"translation":"kjv","book":99,"chapter":7}"#.utf8), forKey: ReaderViewModel.positionKey)
        let model = ReaderViewModel(positionStore: storage) { FakeRepository() }
        #expect(model.location == Location(book: 1, chapter: 1))
        storage.set(Data(#"{"translation":"kjv","book":2,"chapter":70}"#.utf8), forKey: ReaderViewModel.positionKey)
        // FakeRepository: 3 розділи в кожній книзі.
        #expect(ReaderViewModel(positionStore: storage) { FakeRepository() }.location == Location(book: 2, chapter: 3))
    }
}

extension UserDataTests {
    // @trace FR-22
    @Test func testUnavailableDatabaseKeepsWorkingInMemory() {
        struct Broken: Error {}
        let data = UserData(unavailable: Broken())
        #expect(data.lastError != nil)
        data.setNote("n", for: john316)
        #expect(data.note(for: john316)?.text == "n")
    }
}

extension LastPositionTests {
    // @trace FR-25
    @Test func testPositionLivesInUserDatabase() throws {
        let url = try TestSupport.tempDirectory().appendingPathComponent("p/userdata.sqlite")
        do {
            let model = ReaderViewModel(positionStore: try UserDatabase(path: url)) { FakeRepository() }
            model.open(Location(book: 19, chapter: 2))
        }
        let database = try UserDatabase(path: url)
        #expect(ReaderViewModel(positionStore: database) { FakeRepository() }.location == Location(book: 19, chapter: 2))
        database.removeObject(forKey: ReaderViewModel.positionKey)
        #expect(database.data(forKey: ReaderViewModel.positionKey) == nil)
        #expect(try UserDatabase.defaultURL(profile: "x").path.hasSuffix("Bible Reader/x/userdata.sqlite"))
    }
}

extension UserDataTests {
    // @trace FR-24
    @Test func testFailedWriteKeepsMemoryInSyncWithDatabase() throws {
        let database = try UserDatabase.inMemory()
        let data = UserData(database: database)
        try database.queue.write { try $0.execute(sql: "DROP TABLE note; DROP TABLE highlight") }
        data.setNote("n", for: john316)
        #expect(data.note(for: john316) == nil)
        #expect(data.lastError != nil)
        data.setHighlight(.yellow, for: [john316])
        #expect(data.highlight(for: john316) == nil)
        data.dismissError()
        #expect(data.lastError == nil)
        #expect(!data.isInMemoryOnly)
    }
}

extension UserDataTests {
    // @trace FR-24
    @Test func testOrderingIdsAndTitles() throws {
        let data = try makeData()
        let keys = [VerseKey(book: 43, chapter: 3, verse: 17), john316, VerseKey(book: 1, chapter: 2, verse: 1)]
        for key in keys { data.setNote("слово \(key.verse)", for: key) }
        data.setHighlight(.green, for: keys)
        #expect(data.sortedNotes.map(\.id) == keys.sorted())
        #expect(data.searchNotes("слово").map(\.key) == keys.sorted())
        data.toggleBookmark(.init(book: 43, chapter: 3, verse: 16))
        data.toggleBookmark(.init(book: 43, chapter: 3, verse: nil))
        data.toggleBookmark(.init(book: 1, chapter: 1, verse: 2))
        #expect(data.bookmarks.map(\.id) == [.init(book: 1, chapter: 1, verse: 2), .init(book: 43, chapter: 3, verse: nil),
                                             .init(book: 43, chapter: 3, verse: 16)])
        let export = try JSONDecoder.userData.decode(UserDataExport.self, from: data.exportJSON())
        #expect(export.highlights.map(\.key) == keys.sorted())
        #expect(data.exportMarkdown(in: .synodal).contains("зелений"))
        #expect(Set(HighlightColor.allCases.map(\.title)).count == HighlightColor.allCases.count)
    }

    // @trace FR-22
    @Test func testFailedBookmarkWriteKeepsMemory() throws {
        let database = try UserDatabase.inMemory()
        let data = UserData(database: database)
        data.toggleBookmark(.init(book: 1, chapter: 1, verse: 1))
        try database.queue.write { try $0.execute(sql: "DROP TABLE bookmark") }
        data.toggleBookmark(.init(book: 1, chapter: 1, verse: 1))
        data.toggleBookmark(.init(book: 1, chapter: 1, verse: 2))
        data.setNote("", for: john316)
        #expect(data.bookmarks.map(\.target) == [.init(book: 1, chapter: 1, verse: 1)])
    }
}
