import Testing
@testable import BibleCore

@Suite struct StemmerTests {
    private func same(_ language: Language, _ words: [String]) -> Bool {
        let stemmer = Stemmer(language: language)
        return Set(words.map { stemmer.stem($0) }).count == 1
    }

    // @trace FR-18
    @Test func testEnglishIncludingKjvForms() {
        #expect(same(.english, ["love", "loved", "loveth", "lovest", "loving", "Loves"]))
        #expect(same(.english, ["come", "cometh", "comest"]))
        #expect(same(.english, ["walk", "walketh", "walked"]))
        // Слова на -est, які не є формами дієслова, не зливаються з іншими.
        #expect(!same(.english, ["priest", "pries"]))
        #expect(!same(.english, ["beast", "be"]))
    }

    // @trace FR-18
    @Test func testRussian() {
        #expect(same(.russian, ["любовь", "любви", "любовью"]))
        #expect(same(.russian, ["Бог", "Бога", "Богу"]))
    }

    // @trace FR-18
    @Test func testUkrainian() {
        #expect(same(.ukrainian, ["любов", "любові"]))
        #expect(same(.ukrainian, ["Бог", "Бога", "Богові", "Богом"]))
        #expect(same(.ukrainian, ["полюбив", "полюбила", "полюбили"]))
        #expect(same(.ukrainian, ["земля", "землі", "землю", "землею"]))
    }

    // @trace FR-18
    @Test func testCzech() {
        #expect(same(.czech, ["láska", "lásky", "lásku", "láskou"]))
        #expect(same(.czech, ["země", "zemi", "zemí"]))
    }

    // @trace FR-18
    @Test func testCzechNormalization() {
        #expect(Stemmer.czech("xxčt") == "xxck")
        #expect(Stemmer.czech("xxšt") == "xxsk")
        #expect(Stemmer.czech("kůň") == "koň")
        #expect(Stemmer.czech("otec") == "otek")
        #expect(Stemmer.czech("kněz") == "kněh")
        // Запит без діакритики дає ту саму основу, що й текст із нею.
        #expect(Stemmer(language: .czech).stem("Bůh") == Stemmer(language: .czech).stem("buh"))
    }

    // @trace FR-18
    @Test func testWordsSplitLikeTheIndex() {
        // Апостроф і розділові знаки ділять слова так само, як unicode61.
        #expect(Stemmer.words(in: "п'ять, любов’ю!").map(\.text) == ["п", "ять", "любов", "ю"])
        #expect(Stemmer(language: .ukrainian).stemmed("Любов’ю Бога") == "люб ю бог")
        #expect(Stemmer(language: .russian).stemmed("Её") == Stemmer(language: .russian).stemmed("ее"))
        #expect(SearchText.fold("Ёж ёж") == "Еж еж")
    }
}
