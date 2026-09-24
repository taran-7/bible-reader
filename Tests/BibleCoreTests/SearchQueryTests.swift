import Testing
@testable import BibleCore

@Suite struct SearchQueryTests {
    @Test func testQuotesTokens() {
        #expect(SearchQuery.fts("love  one another") == #""love" "one" "another""#)
        #expect(SearchQuery.fts(#"say "hi"*"#) == #""say" """hi""*""#)
    }

    @Test func testEmptyQueryIsNil() {
        #expect(SearchQuery.fts("") == nil)
        #expect(SearchQuery.fts("   \n ") == nil)
    }
}
