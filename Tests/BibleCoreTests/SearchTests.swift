import Testing
@testable import BibleCore

@Suite struct SearchTests {
    let repository = try! SQLiteBibleRepository(path: TestSupport.realDatabase)

    // @trace FR-11
    @Test func testLatin() throws {
        let results = try repository.search("love", translation: .kjv)
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.verse.text.lowercased().contains("love") && $0.verse.translation == .kjv })
        #expect(results.map(\.verse.book) == results.map(\.verse.book).sorted())
    }

    // @trace FR-11
    @Test func testAllWordsRequired() throws {
        let results = try repository.search("God so loved", translation: .kjv)
        #expect(results.contains { $0.verse.book == 43 && $0.verse.chapter == 3 && $0.verse.verse == 16 })
        #expect(results.allSatisfy { $0.verse.text.contains("loved") })
    }

    // @trace FR-11
    @Test func testCyrillicCaseInsensitive() throws {
        let upper = try repository.search("ЛЮБОВЬ", translation: .synodal)
        let lower = try repository.search("любовь", translation: .synodal)
        #expect(!lower.isEmpty)
        #expect(upper.map(\.verse.id) == lower.map(\.verse.id))
    }

    // @trace FR-11
    @Test func testOnlyActiveTranslation() throws {
        #expect(try repository.search("любовь", translation: .kjv).isEmpty)
    }

    // @trace FR-11
    @Test func testSnippetHighlightsMatch() throws {
        let result = try #require(try repository.search("возлюбил", translation: .synodal).first)
        let highlighted = result.segments.filter(\.isMatch).map { $0.text.lowercased() }
        #expect(highlighted.contains("возлюбил"))
        #expect(result.segments.map(\.text).joined().contains("возлюбил") || result.segments.map(\.text).joined().contains("Возлюбил"))
    }

    // @trace FR-12
    @Test(arguments: [#""love*"#, "(", ")", ":", "-", "\"", "AND", "NOT love", "love OR", "*", "^", "NEAR("])
    func testSpecialCharactersDoNotThrow(query: String) throws {
        _ = try repository.search(query, translation: .kjv)
    }

    // @trace FR-12
    @Test func testEmptyQuery() throws {
        #expect(try repository.search("  ", translation: .kjv).isEmpty)
    }

    // @trace FR-11
    @Test func testLimit() throws {
        #expect(try repository.search("the", translation: .kjv, limit: 5).count == 5)
    }
}
