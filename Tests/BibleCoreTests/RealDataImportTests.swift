import Testing
@testable import BibleCore

@Suite struct RealDataImportTests {
    let db = TestSupport.realDatabase

    // @trace FR-1
    @Test func testSixtySixBooksPerTranslation() throws {
        for translation in Translation.allCases {
            #expect(try TestSupport.count("SELECT COUNT(DISTINCT book) FROM verses WHERE translation = '\(translation.rawValue)'", in: db) == 66)
        }
    }

    // @trace FR-1
    @Test func testKjvVerseCount() throws {
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses WHERE translation = 'kjv'", in: db) == 31_102)
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses_fts", in: db) == TestSupport.count("SELECT COUNT(*) FROM verses", in: db))
    }

    // @trace FR-1
    @Test func testControlVerses() throws {
        func text(_ t: Translation, _ b: Int, _ c: Int, _ v: Int) throws -> String {
            try TestSupport.string("SELECT text FROM verses WHERE translation = '\(t.rawValue)' AND book = \(b) AND chapter = \(c) AND verse = \(v)", in: db) ?? ""
        }
        #expect(try text(.kjv, 1, 1, 1).hasPrefix("In the beginning God created"))
        #expect(try text(.synodal, 1, 1, 1).hasPrefix("В начале сотворил Бог"))
        #expect(try text(.kjv, 43, 3, 16).hasPrefix("For God so loved the world"))
        #expect(try text(.synodal, 43, 3, 16).hasPrefix("Ибо так возлюбил Бог мир"))
        #expect(try text(.ohienko, 1, 1, 1).hasPrefix("На початку Бог створив"))
        #expect(try text(.ohienko, 43, 3, 16).hasPrefix("Так бо Бог полюбив світ"))
        #expect(try text(.bkr, 1, 1, 1).hasPrefix("Na počátku stvořil Bůh"))
        #expect(try text(.bkr, 43, 3, 16).hasPrefix("Nebo tak Bůh miloval svět"))
    }

    // @trace FR-29
    @Test func testNewTranslationsAreClean() throws {
        // Без знаків наголосу, тегів і фігурних дужок.
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses WHERE translation IN ('ohienko','bkr') AND (text LIKE '%' || char(769) || '%' OR text LIKE '%<%' OR text LIKE '%{%')", in: db) == 0)
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses WHERE translation = 'bkr'", in: db) == 31_102)
        #expect(try TestSupport.count("SELECT MAX(chapter) FROM verses WHERE translation = 'bkr' AND book = 19", in: db) == 150)
    }
}
