import Testing
@testable import BibleCore

@Suite struct SearchQueryTests {
    // @trace FR-12
    @Test func testQuotesTokens() {
        #expect(SearchQuery.fts("love  one another") == #""love" "one" "another""#)
        #expect(SearchQuery.fts(#"say "hi"*"#) == #""say" """hi""*""#)
    }

    // @trace FR-12
    @Test func testEmptyQueryIsNil() {
        #expect(SearchQuery.fts("") == nil)
        #expect(SearchQuery.fts("   \n ") == nil)
    }
}
