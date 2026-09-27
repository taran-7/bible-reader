import Testing
@testable import BibleCore

@Suite struct TranslationTests {
    // @trace FR-28
    @Test func testFourTranslationsWithLanguages() {
        #expect(Translation.allCases == [.kjv, .synodal, .ohienko, .bkr])
        #expect(Translation.allCases.map(\.language) == [.english, .russian, .ukrainian, .czech])
        #expect(Translation.allCases.map(\.title) == ["KJV", "Синодальний", "Огієнко", "Kralická"])
        #expect(Translation.allCases.map(\.sourceFileName) == ["en_kjv.json", "ru_synodal.json", "uk_ohienko.json", "cs_bkr.json"])
        #expect(Translation.allCases.map(\.menuTitle) == ["KJV — English", "Синодальний — русский", "Огієнко — українська", "Kralická — čeština"])
        #expect(Translation.bkr.menuTitle == "Kralická — čeština")
    }

    // @trace FR-28
    @Test func testUkrainianBookNames() {
        #expect(Book(number: 1)?.name(in: .ohienko) == "Буття")
        #expect(Book(number: 43)?.name(in: .ohienko) == "Від Івана")
        #expect(Book(number: 43)?.abbreviation(in: .ohienko) == "Ів")
        #expect(Book(number: 46)?.name(in: .ohienko) == "1 до коринтян")
        #expect(Book(number: 66)?.name(in: .ohienko) == "Об'явлення")
    }

    // @trace FR-29
    @Test func testCzechBookNames() {
        #expect(Book(number: 1)?.name(in: .bkr) == "Genesis")
        #expect(Book(number: 43)?.name(in: .bkr) == "Jan")
        #expect(Book(number: 43)?.abbreviation(in: .bkr) == "J")
        #expect(Book(number: 19)?.name(in: .bkr) == "Žalmy")
        #expect(Book(number: 46)?.name(in: .bkr) == "1. Korintským")
    }

    // @trace FR-28
    @Test func testEveryBookHasAllLanguages() {
        for book in Book.all {
            for translation in Translation.allCases {
                #expect(!book.name(in: translation).isEmpty && !book.abbreviation(in: translation).isEmpty, "\(book.number) \(translation)")
            }
        }
    }

    // @trace FR-28
    @Test func testParsesUkrainianAndCzech() {
        #expect(Reference.parse("Ів 3:16") == Reference(book: 43, chapter: 3, verseStart: 16))
        #expect(Reference.parse("Від Івана 3:16") == Reference(book: 43, chapter: 3, verseStart: 16))
        #expect(Reference.parse("Буття 1") == Reference(book: 1, chapter: 1))
        #expect(Reference.parse("Об'явлення 22:21")?.book == 66)
        #expect(Reference.parse("J 3:16") == Reference(book: 43, chapter: 3, verseStart: 16))
        #expect(Reference.parse("1K 13:4-7") == Reference(book: 46, chapter: 13, verseStart: 4, verseEnd: 7))
        #expect(Reference.parse("1. Korintským 13") == Reference(book: 46, chapter: 13))
        #expect(Reference.parse("Žalmy 23")?.book == 19)
        #expect(Reference.parse("Gn 1:1")?.book == 1)
        #expect(Reference.parse("Dn 7")?.book == 27)
        // Короткі чеські форми, що збігаються зі звичними англійськими: `Jon` — Йона, як і в англійській.
        #expect(Reference.parse("Jon 3")?.book == 32)
        #expect(Reference.parse("Na 1")?.book == 34)
    }

    // @trace FR-28
    @Test func testSpellingsAreUnambiguous() {
        var owner: [String: Int] = [:]
        for book in Book.all {
            for spelling in book.spellings {
                let key = Reference.normalize(spelling)
                if let other = owner[key] {
                    #expect(other == book.number, "«\(spelling)» веде і до \(other), і до \(book.number)")
                }
                owner[key] = book.number
            }
        }
    }

    // @trace FR-28
    @Test func testReferenceAndQuoteInTranslationLanguage() {
        #expect(Reference(book: 43, chapter: 3, verseStart: 16).format(in: .ohienko) == "Ів. 3:16")
        #expect(Reference(book: 43, chapter: 3, verseStart: 16).format(in: .bkr) == "J 3:16")
        let uk = Verse(translation: .ohienko, book: 43, chapter: 3, verse: 16, text: "Так бо Бог полюбив світ")
        #expect(Quote.format([uk]) == "«Так бо Бог полюбив світ» (Від Івана 3:16)")
        let cs = Verse(translation: .bkr, book: 43, chapter: 3, verse: 16, text: "Nebo tak Bůh miloval svět")
        #expect(Quote.format([cs]) == "«Nebo tak Bůh miloval svět» (Jan 3:16)")
    }
}
