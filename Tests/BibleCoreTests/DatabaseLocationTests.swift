import Foundation
import Testing
@testable import BibleCore

@Suite struct DatabaseLocationTests {
    let bundled = URL(fileURLWithPath: "/app/bible.sqlite")

    // @trace FR-7
    @Test func testEnvironmentOverridesBundle() throws {
        let url = try DatabaseLocation.url(environment: ["BIBLE_READER_DB": "/tmp/x.sqlite"], bundled: bundled)
        #expect(url.path == "/tmp/x.sqlite")
    }

    // @trace FR-7
    @Test func testEmptyEnvironmentIsIgnored() throws {
        #expect(try DatabaseLocation.url(environment: ["BIBLE_READER_DB": ""], bundled: bundled) == bundled)
        #expect(try DatabaseLocation.url(environment: [:], bundled: bundled) == bundled)
    }

    // @trace FR-7
    @Test func testNoDatabaseThrows() {
        #expect(throws: RepositoryError.self) {
            try DatabaseLocation.url(environment: [:], bundled: nil)
        }
    }
}
