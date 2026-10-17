import Foundation
import Testing
@testable import BibleCore

/// The Synodal prints Greek (Septuagint) additions in square brackets; KJV, based on the Hebrew text, has none of them,
/// so the converter drops the long ones (owner decision 2026-10-17).
@Suite struct SynodalTextTests {
    let db = TestSupport.realDatabase

    func text(_ book: Int, _ chapter: Int, _ verse: Int) throws -> String {
        let sql = "SELECT text FROM verses WHERE translation = 'synodal' AND book = \(book) AND chapter = \(chapter) AND verse = \(verse)"
        return try #require(try TestSupport.string(sql, in: db))
    }

    // @trace FR-1
    @Test func testEstherHasNoGreekAdditions() throws {
        #expect(try TestSupport.count("SELECT count(*) FROM verses WHERE translation = 'synodal' AND book = 17 AND (text LIKE '%[%' OR text LIKE '%]%')", in: db) == 0)
        #expect(try text(17, 1, 1).hasPrefix("И было во дни Артаксеркса, — этот Артаксеркс царствовал"))
        #expect(try text(17, 4, 17) == "И пошел Мардохей и сделал, как приказала ему Есфирь.")
        // Cutting an insertion out must not leave a stray comma before the full stop.
        #expect(!(try text(17, 5, 1)).contains(",."))
    }

    // @trace FR-1
    @Test func testNoLongBracketedInsertionIsLeftInTheOldTestamentExceptHebrewText() throws {
        let hebrew: Set<String> = ["5:21:5", "12:7:13"]
        let rows = try TestSupport.strings("SELECT book || ':' || chapter || ':' || verse || '|' || text FROM verses WHERE translation = 'synodal' AND book <= 39 AND text LIKE '%[%'", in: db)
        var left: [String] = []
        for row in rows {
            let parts = row.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2, !hebrew.contains(parts[0]) else { continue }
            var rest = Substring(parts[1])
            while let open = rest.firstIndex(of: "["), let close = rest[open...].firstIndex(of: "]") {
                if rest.distance(from: open, to: close) + 1 >= 100 { left.append(parts[0]) }
                rest = rest[rest.index(after: close)...]
            }
        }
        // Judges 20:27-28, Ps 67:23-24 and Dan 3:24-90 are multi-verse brackets (Hebrew text or mid-chapter): no single verse holds one.
        #expect(left.isEmpty, "\(left)")
        #expect(try text(5, 21, 5).contains("[ибо их избрал Господь Бог твой"), "Deut 21:5 is Hebrew text and is in KJV")
    }

    // @trace FR-27
    @Test func testChaptersEndingInAGreekAdditionAreAsLongAsInKJV() throws {
        for (book, chapter, count) in [(6, 24, 33), (20, 4, 27)] {
            let synodal = try TestSupport.count("SELECT count(*) FROM verses WHERE translation = 'synodal' AND book = \(book) AND chapter = \(chapter)", in: db)
            let kjv = try TestSupport.count("SELECT count(*) FROM verses WHERE translation = 'kjv' AND book = \(book) AND chapter = \(chapter)", in: db)
            #expect(synodal == count && kjv == count, "\(book):\(chapter) synodal \(synodal), kjv \(kjv)")
        }
    }
}
