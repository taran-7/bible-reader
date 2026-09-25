import Testing
@testable import BibleCore

@Suite struct SearchTests {
    let repository = try! SQLiteBibleRepository(path: TestSupport.realDatabase)

    @Test func testLatin() throws {
        let results = try repository.search("love", translation: .kjv)
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.verse.text.lowercased().contains("love") && $0.verse.translation == .kjv })
        #expect(results.map(\.verse.book) == results.map(\.verse.book).sorted())
    }

    @Test func testAllWordsRequired() throws {
        let results = try repository.search("God so loved", translation: .kjv)
        #expect(results.contains { $0.verse.book == 43 && $0.verse.chapter == 3 && $0.verse.verse == 16 })
        #expect(results.allSatisfy { $0.verse.text.contains("loved") })
    }

    @Test func testCyrillicCaseInsensitive() throws {
        let upper = try repository.search("ЛЮБОВЬ", translation: .synodal)
        let lower = try repository.search("любовь", translation: .synodal)
        #expect(!lower.isEmpty)
        #expect(upper.map(\.verse.id) == lower.map(\.verse.id))
    }

    @Test func testOnlyActiveTranslation() throws {
        #expect(try repository.search("любовь", translation: .kjv).isEmpty)
    }

    @Test func testSnippetHighlightsMatch() throws {
        let result = try #require(try repository.search("возлюбил", translation: .synodal).first)
        let highlighted = result.segments.filter(\.isMatch).map { $0.text.lowercased() }
        #expect(highlighted.contains("возлюбил"))
        #expect(result.segments.map(\.text).joined().contains("возлюбил") || result.segments.map(\.text).joined().contains("Возлюбил"))
    }

    @Test(arguments: [#""love*"#, "(", ")", ":", "-", "\"", "AND", "NOT love", "love OR", "*", "^", "NEAR("])
    func testSpecialCharactersDoNotThrow(query: String) throws {
        _ = try repository.search(query, translation: .kjv)
    }

    @Test func testEmptyQuery() throws {
        #expect(try repository.search("  ", translation: .kjv).isEmpty)
    }

    @Test func testLimit() throws {
        #expect(try repository.search("the", translation: .kjv, limit: 5).count == 5)
    }
}
