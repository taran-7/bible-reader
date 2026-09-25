import Testing
@testable import BibleCore

@Suite struct QuoteTests {
    func verse(_ t: Translation, _ n: Int, _ text: String) -> Verse {
        Verse(translation: t, book: 43, chapter: 3, verse: n, text: text)
    }

    @Test func testReferenceFormat() {
        #expect(Reference(book: 43, chapter: 3, verseStart: 16).format(in: .synodal) == "Ин. 3:16")
        #expect(Reference(book: 46, chapter: 13, verseStart: 4, verseEnd: 7).format(in: .synodal) == "1 Кор. 13:4-7")
        #expect(Reference(book: 43, chapter: 3).format(in: .kjv) == "John 3")
        #expect(Reference(book: 1, chapter: 1, verseStart: 1).format(in: .kjv) == "Gen 1:1")
    }

    @Test func testSingleVerseSynodal() {
        let quote = Quote.format([verse(.synodal, 16, "Ибо так возлюбил Бог мир…")])
        #expect(quote == "«Ибо так возлюбил Бог мир…» (От Иоанна 3:16)")
    }

    @Test func testRangeKjv() {
        let quote = Quote.format([verse(.kjv, 16, "a"), verse(.kjv, 17, "b"), verse(.kjv, 18, "c")])
        #expect(quote?.hasSuffix("(John 3:16-18)") == true)
        let kings = Quote.format([Verse(translation: .kjv, book: 12, chapter: 4, verse: 16, text: "a")])
        #expect(kings == "«a» (2 Kings 4:16)")
    }

    @Test func testJoinsTextsWithSpace() {
        let quote = Quote.format([verse(.kjv, 17, "b"), verse(.kjv, 16, "a")])
        #expect(quote == "«a b» (John 3:16-17)")
    }

    @Test func testNonContiguousSelection() {
        let quote = Quote.format([verse(.kjv, 16, "a"), verse(.kjv, 17, "b"), verse(.kjv, 19, "d")])
        #expect(quote == "«a b d» (John 3:16-17,19)")
    }

    @Test func testEmptySelection() {
        #expect(Quote.format([]) == nil)
    }
}
