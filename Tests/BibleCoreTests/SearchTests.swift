import Testing
@testable import BibleCore

@Suite struct SearchTests {
    let repository = try! SQLiteBibleRepository(path: TestSupport.realDatabase)

    // @trace FR-11
    @Test func testLatin() throws {
        let results = try repository.search("love", translation: .kjv)
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.verse.text.lowercased().contains("lov") && $0.verse.translation == .kjv })
        #expect(results.map(\.verse.book) == results.map(\.verse.book).sorted())
    }

    // @trace FR-11
    @Test func testAllWordsRequired() throws {
        let results = try repository.search("God so loved", translation: .kjv)
        #expect(results.contains { $0.verse.book == 43 && $0.verse.chapter == 3 && $0.verse.verse == 16 })
        #expect(results.allSatisfy { $0.verse.text.lowercased().contains("lov") })
    }

    // @trace FR-11
    @Test func testCyrillicCaseInsensitive() throws {
        let upper = try repository.search("ЛЮБОВЬ", translation: .synodal)
        let lower = try repository.search("любовь", translation: .synodal)
        #expect(!lower.isEmpty)
        #expect(upper.map(\.verse.id) == lower.map(\.verse.id))
    }

    // @trace FR-2
    @Test func testYoFoldsToYe() throws {
        let results = try repository.search("четвертый", translation: .synodal)
        let withYo = try #require(results.first { $0.verse.text.contains("четвёртый") })
        // The snippet shows the original text with «ё», not the folded one.
        #expect(withYo.segments.filter(\.isMatch).contains { $0.text.lowercased() == "четвёртый" })
        #expect(try repository.search("четвёртый", translation: .synodal).map(\.verse.id) == results.map(\.verse.id))
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

    // @trace FR-18
    @Test func testMorphologyRussianAndEnglish() throws {
        let russian = try repository.search("любовь", translation: .synodal)
        for form in ["любви", "любовью"] {
            #expect(russian.contains { $0.verse.text.lowercased().contains(form) }, "\(form)")
        }
        let english = try repository.search("love", translation: .kjv, limit: 2_000)
        for form in ["loved", "loveth", "loving"] {
            #expect(english.contains { $0.verse.text.lowercased().contains(form) }, "\(form)")
        }
    }

    // @trace FR-18
    @Test func testMorphologyUkrainianAndCzech() throws {
        let ukrainian = try repository.search("любов", translation: .ohienko, limit: 2_000)
        #expect(ukrainian.contains { $0.verse.text.lowercased().contains("любові") })
        let czech = try repository.search("láska", translation: .bkr, limit: 2_000)
        #expect(czech.contains { $0.verse.text.lowercased().contains("lásky") })
    }

    // @trace FR-18
    @Test func testMorphologyHighlightsEveryForm() throws {
        let result = try #require(try repository.search("love", translation: .kjv, limit: 2_000)
            .first { $0.verse.book == 43 && $0.verse.chapter == 3 && $0.verse.verse == 16 })
        #expect(result.segments.filter(\.isMatch).map(\.text) == ["loved"])
        // The segments add up to the full verse text.
        #expect(result.segments.map(\.text).joined() == result.verse.text)
    }

    // @trace FR-21
    @Test func testQuotedPhraseIsExact() throws {
        let phrase = try repository.search(#""only begotten Son""#, translation: .kjv)
        #expect(phrase.contains { $0.verse.book == 43 && $0.verse.chapter == 3 && $0.verse.verse == 16 })
        #expect(phrase.allSatisfy { $0.verse.text.lowercased().contains("only begotten son") })
        #expect(phrase.first?.segments.filter(\.isMatch).map { $0.text.lowercased() } == ["only", "begotten", "son"])
        // Phrase words outside the phrase are not highlighted: in Genesis 1:1 only "In the beginning", not the second "the".
        let genesis = try #require(try repository.search(#""in the beginning""#, translation: .kjv).first)
        #expect(genesis.segments.filter(\.isMatch).map(\.text) == ["In", "the", "beginning"])
        // Exact form: a quoted "loved" does not find "love".
        let exact = try repository.search(#""loved""#, translation: .kjv, limit: 2_000)
        #expect(!exact.isEmpty)
        #expect(exact.allSatisfy { SearchText.fold($0.verse.text).lowercased().contains("loved") })
        #expect(try repository.search("«так возлюбил Бог мир»", translation: .synodal).count == 1)
    }

    // @trace FR-19
    @Test func testScope() throws {
        let all = try repository.searchPage("love", translation: .kjv, scope: .bible, offset: 0, limit: 10)
        let old = try repository.searchPage("love", translation: .kjv, scope: .oldTestament, offset: 0, limit: 10)
        let new = try repository.searchPage("love", translation: .kjv, scope: .newTestament, offset: 0, limit: 10)
        let john = try repository.searchPage("love", translation: .kjv, scope: .book(43), offset: 0, limit: 1_000)
        #expect(old.total > 0 && new.total > 0)
        #expect(old.total + new.total == all.total)
        #expect(old.results.allSatisfy { $0.verse.book <= 39 })
        #expect(new.results.allSatisfy { $0.verse.book >= 40 })
        #expect(john.total == john.results.count && john.results.allSatisfy { $0.verse.book == 43 })
    }

    // @trace FR-20
    @Test func testPagingCoversAllResults() throws {
        let first = try repository.searchPage("the", translation: .kjv, scope: .bible, offset: 0, limit: 100)
        #expect(first.total > 20_000)
        #expect(first.results.count == 100)
        let second = try repository.searchPage("the", translation: .kjv, scope: .bible, offset: 100, limit: 100)
        #expect(second.total == first.total)
        #expect(Set(first.results.map(\.id)).isDisjoint(with: second.results.map(\.id)))
        let firstIDs = first.results.map(\.id), secondIDs = second.results.map(\.id)
        #expect(firstIDs.last.map { last in secondIDs.first.map { SearchTests.order($0) > SearchTests.order(last) } ?? false } == true)
        let tail = try repository.searchPage("the", translation: .kjv, scope: .bible, offset: first.total - 3, limit: 100)
        #expect(tail.results.count == 3)
    }

    static func order(_ id: VerseID) -> Int { id.book * 1_000_000 + id.chapter * 1_000 + id.verse }

    // @trace NFR-3
    @Test func testSearchIsFastOnWholeBible() throws {
        // The most frequent words of each language: the worst case for counting and the first page.
        for (query, translation) in [("the", Translation.kjv), ("и", .synodal), ("і", .ohienko), ("a", .bkr), (#""and the""#, .kjv)] {
            _ = try repository.searchPage(query, translation: translation, scope: .bible, offset: 0, limit: 100)
            let clock = ContinuousClock()
            let times = try (0..<3).map { _ in
                try clock.measure { _ = try repository.searchPage(query, translation: translation, scope: .bible, offset: 0, limit: 100) }
            }
            let best = try #require(times.min())
            #expect(best < .milliseconds(200), "\(query): \(best)")
        }
    }

    // @trace FR-28
    @Test func testSearchInUkrainianAndCzech() throws {
        let uk = try repository.search("полюбив світ", translation: .ohienko)
        #expect(uk.contains { $0.verse.book == 43 && $0.verse.chapter == 3 && $0.verse.verse == 16 })
        // Without Czech diacritics: «buh miloval» finds «Bůh miloval».
        let cs = try repository.search("buh miloval", translation: .bkr)
        #expect(cs.contains { $0.verse.book == 43 && $0.verse.chapter == 3 && $0.verse.verse == 16 })
    }

    // @trace FR-28
    @Test func testUkrainianApostropheVariants() throws {
        // The data has an ASCII apostrophe; a macOS layout may give ’ or ʼ.
        for query in ["п'ять", "п’ять", "пʼять"] {
            #expect(try !repository.search(query, translation: .ohienko).isEmpty, "\(query)")
        }
        #expect(SearchText.fold("пʼять і п’ять") == "п'ять і п'ять")
    }
}

