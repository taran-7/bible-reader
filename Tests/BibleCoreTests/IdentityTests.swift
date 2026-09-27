import Testing
@testable import BibleCore

/// Ідентичність для списків SwiftUI і підписи перекладів у тулбарі.
@Suite struct IdentityTests {
    // @trace FR-4
    @Test func testTranslationTitles() {
        #expect(Translation.allCases.map(\.title) == ["KJV", "Синодальний", "Огієнко", "Kralická"])
    }

    // @trace FR-4
    @Test func testBookIdIsNumber() {
        #expect(Book.all.map(\.id) == Array(1...66))
    }

    // @trace FR-14
    @Test func testSearchResultIdIsVerse() {
        let verse = Verse(translation: .kjv, book: 43, chapter: 3, verse: 16, text: "x")
        #expect(SearchResult(verse: verse, segments: []).id == verse.id)
    }
}
