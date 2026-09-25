import Foundation
import Testing
@testable import BibleCore

@Suite struct RepositoryTests {
    let repository = try! SQLiteBibleRepository(path: TestSupport.realDatabase)

    // @trace FR-6
    @Test func testChapterCount() throws {
        #expect(try repository.chapterCount(book: 1, translation: .kjv) == 50)
        #expect(try repository.chapterCount(book: 19, translation: .kjv) == 150)
        #expect(try repository.chapterCount(book: 99, translation: .kjv) == 0)
    }

    // @trace FR-6
    @Test func testVersesOfJohn3() throws {
        let verses = try repository.verses(book: 43, chapter: 3, translation: .synodal)
        #expect(verses.count == 36)
        #expect(verses.map(\.verse) == Array(1...36))
        #expect(verses[15].text.hasPrefix("Ибо так возлюбил Бог мир"))
        #expect(verses.allSatisfy { $0.translation == .synodal && $0.book == 43 && $0.chapter == 3 })
    }

    // @trace FR-5
    @Test func testBooksOfTranslation() throws {
        #expect(try repository.books(translation: .synodal).count == 66)
    }

    // @trace FR-7
    @Test func testMissingDatabaseThrows() throws {
        let missing = try TestSupport.tempDirectory().appendingPathComponent("nope.sqlite")
        #expect(throws: RepositoryError.self) {
            try SQLiteBibleRepository(path: missing)
        }
        #expect(!FileManager.default.fileExists(atPath: missing.path))
    }

    // @trace FR-7
    @Test func testCorruptDatabaseThrows() throws {
        let corrupt = try TestSupport.tempDirectory().appendingPathComponent("bad.sqlite")
        try Data("not a database".utf8).write(to: corrupt)
        #expect(throws: RepositoryError.self) {
            try SQLiteBibleRepository(path: corrupt)
        }
    }
}
