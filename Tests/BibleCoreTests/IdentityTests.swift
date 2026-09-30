import Testing
@testable import BibleCore

/// Identity for SwiftUI lists and translation labels in the toolbar.
@Suite struct IdentityTests {
    // @trace FR-4
    @Test func testTranslationTitles() {
        #expect(Translation.allCases.map(\.title) == ["KJV", "Kralická", "Огієнко", "Синодальний"])
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
