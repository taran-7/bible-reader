import Testing
@testable import BibleCore

@Suite struct ReferenceParseTests {
    @Test func testRussianAbbrevWithVerse() {
        #expect(Reference.parse("Ин 3:16") == Reference(book: 43, chapter: 3, verseStart: 16))
    }

    @Test func testEnglishChapterOnly() {
        #expect(Reference.parse("John 3") == Reference(book: 43, chapter: 3))
        #expect(Reference.parse("  john   3 ") == Reference(book: 43, chapter: 3))
    }

    @Test func testRange() {
        #expect(Reference.parse("ин. 3:16-18") == Reference(book: 43, chapter: 3, verseStart: 16, verseEnd: 18))
        #expect(Reference.parse("John 3:16–18") == Reference(book: 43, chapter: 3, verseStart: 16, verseEnd: 18))
    }

    @Test func testNumberedBooks() {
        #expect(Reference.parse("1 Кор 13:4") == Reference(book: 46, chapter: 13, verseStart: 4))
        #expect(Reference.parse("1 Cor 13:4") == Reference(book: 46, chapter: 13, verseStart: 4))
        #expect(Reference.parse("1Ин 4:8") == Reference(book: 62, chapter: 4, verseStart: 8))
    }

    @Test func testMultiWordNames() {
        #expect(Reference.parse("От Иоанна 3:16") == Reference(book: 43, chapter: 3, verseStart: 16))
        #expect(Reference.parse("Song of Solomon 2") == Reference(book: 22, chapter: 2))
    }

    @Test func testNotAReference() {
        #expect(Reference.parse("любовь") == nil)
        #expect(Reference.parse("Xyz 3:16") == nil)
        #expect(Reference.parse("3:16") == nil)
        #expect(Reference.parse("John 0") == nil)
        #expect(Reference.parse("John 3:18-16") == nil)
        #expect(Reference.parse("") == nil)
    }

    @Test func testAllBooksRoundTrip() {
        for book in Book.all {
            for spelling in book.spellings {
                #expect(Reference.parse("\(spelling) 1:1")?.book == book.number, "\(spelling)")
                #expect(Reference.parse("\(spelling). 1")?.book == book.number, "\(spelling).")
            }
            for translation in Translation.allCases {
                let ref = Reference(book: book.number, chapter: 2, verseStart: 3, verseEnd: 4)
                #expect(Reference.parse(ref.format(in: translation)) == ref, "\(ref.format(in: translation))")
            }
        }
    }
}
