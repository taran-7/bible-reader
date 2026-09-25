import Testing
@testable import BibleCore

@Suite struct RealDataImportTests {
    let db = TestSupport.realDatabase

    @Test func testSixtySixBooksPerTranslation() throws {
        for translation in Translation.allCases {
            #expect(try TestSupport.count("SELECT COUNT(DISTINCT book) FROM verses WHERE translation = '\(translation.rawValue)'", in: db) == 66)
        }
    }

    @Test func testKjvVerseCount() throws {
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses WHERE translation = 'kjv'", in: db) == 31_102)
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses_fts", in: db) == TestSupport.count("SELECT COUNT(*) FROM verses", in: db))
    }

    @Test func testControlVerses() throws {
        func text(_ t: Translation, _ b: Int, _ c: Int, _ v: Int) throws -> String {
            try TestSupport.string("SELECT text FROM verses WHERE translation = '\(t.rawValue)' AND book = \(b) AND chapter = \(c) AND verse = \(v)", in: db) ?? ""
        }
        #expect(try text(.kjv, 1, 1, 1).hasPrefix("In the beginning God created"))
        #expect(try text(.synodal, 1, 1, 1).hasPrefix("В начале сотворил Бог"))
        #expect(try text(.kjv, 43, 3, 16).hasPrefix("For God so loved the world"))
        #expect(try text(.synodal, 43, 3, 16).hasPrefix("Ибо так возлюбил Бог мир"))
    }
}
