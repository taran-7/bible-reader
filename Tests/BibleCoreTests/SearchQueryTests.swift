import Testing
@testable import BibleCore

@Suite struct SearchQueryTests {
    // @trace FR-12
    @Test func testWordsAreQuotedForFts() {
        let query = SearchQuery.parse("love  one another")
        #expect(query?.words == ["love", "one", "another"])
        #expect(query?.phrases == [])
        #expect(SearchQuery.fts(words: ["say", "hi\"*"]) == #""say" "hi""*""#)
    }

    // @trace FR-12
    @Test func testEmptyQueryIsNil() {
        #expect(SearchQuery.parse("") == nil)
        #expect(SearchQuery.parse("   \n ") == nil)
        #expect(SearchQuery.parse("\"\"") == nil)
        #expect(SearchQuery.parse("*(-:") == nil)
    }

    // @trace FR-21
    @Test func testQuotedPhrase() {
        for text in [#""only begotten Son""#, "«only begotten Son»", "„only begotten Son“", "“only begotten Son”"] {
            let query = SearchQuery.parse(text)
            #expect(query?.phrases == [["only", "begotten", "son"]], "\(text)")
            #expect(query?.words == [], "\(text)")
        }
        let mixed = SearchQuery.parse(#"love "one another""#)
        #expect(mixed?.words == ["love"])
        #expect(mixed?.phrases == [["one", "another"]])
        #expect(SearchQuery.fts(phrases: [["one", "another"], ["love"]]) == #""one another" "love""#)
    }

    // @trace FR-12
    @Test func testUnmatchedQuoteIsText() {
        let query = SearchQuery.parse(#""love*"#)
        #expect(query?.words == ["love"])
        #expect(query?.phrases == [])
    }

    // @trace FR-19
    @Test func testScopeBooks() {
        #expect(SearchScope.bible.books == 1...66)
        #expect(SearchScope.oldTestament.books == 1...39)
        #expect(SearchScope.newTestament.books == 40...66)
        #expect(SearchScope.book(43).books == 43...43)
    }
}
