import Testing
@testable import BibleCore

@Suite struct VerseTests {
    @Test func testIdentity() {
        let a = Verse(translation: .kjv, book: 43, chapter: 3, verse: 16, text: "For God so loved")
        let b = Verse(translation: .kjv, book: 43, chapter: 3, verse: 16, text: "інший текст")
        let c = Verse(translation: .synodal, book: 43, chapter: 3, verse: 16, text: "For God so loved")
        #expect(a.id == b.id)
        #expect(a.id != c.id)
    }
}
