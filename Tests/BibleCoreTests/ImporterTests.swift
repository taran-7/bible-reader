import Foundation
import Testing
@testable import BibleCore

@Suite struct ImporterTests {
    // @trace FR-1
    @Test func testImportsFixture() throws {
        let dir = try TestSupport.tempDirectory()
        try TestSupport.writeFixture(to: dir)
        let out = dir.appendingPathComponent("bible.sqlite")
        try BibleImporter.run(rawDirectory: dir, output: out)

        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses", in: out) == 16)
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses WHERE translation = 'kjv' AND book = 2 AND chapter = 2 AND verse = 1", in: out) == 1)
        #expect(try TestSupport.string("SELECT text FROM verses WHERE translation = 'synodal' AND book = 1 AND chapter = 1 AND verse = 1", in: out) == "В начале сотворил Бог небо и землю.")
    }

    // @trace FR-3
    @Test func testTruncatedSourceFailsWithoutOutput() throws {
        let dir = try TestSupport.tempDirectory()
        try TestSupport.writeFixture(to: dir)  // 2 books in each file
        let out = dir.appendingPathComponent("bible.sqlite")

        #expect(throws: ImportError.incomplete(Translation.kjv.sourceFileName, books: 2, expected: 66)) {
            try BibleImporter.run(rawDirectory: dir, output: out, expectedBooks: 66)
        }
        #expect(!FileManager.default.fileExists(atPath: out.path))
    }

    // @trace FR-3
    @Test func testCommandUsageErrorExits64() {
        var stderr = ""
        let code = ImportCommand.run(arguments: ["bible-import"], stderr: { stderr += $0 })
        #expect(code == 64)
        #expect(stderr.hasPrefix("Використання:"))
    }

    // @trace FR-3
    @Test func testCommandImportsFullCanon() throws {
        let dir = try TestSupport.tempDirectory()
        let canon = "[" + (1...66).map { #"{"chapters":[["Verse \#($0)."]]}"# }.joined(separator: ",") + "]"
        try TestSupport.writeFixture(to: dir, kjv: canon, synodal: canon, ohienko: canon, bkr: canon)
        let out = dir.appendingPathComponent("bible.sqlite")
        var stderr = ""
        #expect(ImportCommand.run(arguments: ["bible-import", dir.path, out.path], stderr: { stderr += $0 }) == 0)
        #expect(stderr.isEmpty)
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses", in: out) == 66 * 4)
    }

    // @trace FR-3
    @Test func testCommandImportErrorExits1WithMessage() throws {
        let dir = try TestSupport.tempDirectory()
        try TestSupport.writeFixture(to: dir)
        let out = dir.appendingPathComponent("db/bible.sqlite")
        var stderr = ""
        let code = ImportCommand.run(arguments: ["bible-import", dir.path, out.path], stderr: { stderr += $0 })
        #expect(code == 1)
        #expect(stderr.contains("Помилка:"))
        #expect(stderr.contains(Translation.kjv.sourceFileName))
        #expect(!FileManager.default.fileExists(atPath: out.path))
    }

    // @trace FR-1
    @Test func testStripsMarkup() throws {
        let dir = try TestSupport.tempDirectory()
        let kjv = "\u{FEFF}" + #"[{"abbrev":"gn","name":"Genesis","chapters":[["And the earth was {without} form."]]}]"#
        try TestSupport.writeFixture(to: dir, kjv: kjv)
        let out = dir.appendingPathComponent("bible.sqlite")
        try BibleImporter.run(rawDirectory: dir, output: out)

        #expect(try TestSupport.string("SELECT text FROM verses WHERE translation = 'kjv'", in: out) == "And the earth was without form.")
    }

    // @trace FR-2
    @Test func testFtsRowCountMatchesVerses() throws {
        let dir = try TestSupport.tempDirectory()
        try TestSupport.writeFixture(to: dir)
        let out = dir.appendingPathComponent("bible.sqlite")
        try BibleImporter.run(rawDirectory: dir, output: out)

        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses_fts", in: out) == 16)
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses_fts WHERE verses_fts MATCH 'НАЧАЛЕ'", in: out) == 1)
    }

    // @trace FR-2
    @Test func testFtsIgnoresDiacritics() throws {
        let dir = try TestSupport.tempDirectory()
        let kjv = #"[{"abbrev":"gn","name":"Genesis","chapters":[["A naïve café."]]}]"#
        let synodal = #"[{"abbrev":"1","name":"Genesis","chapters":[["Всё ещё здесь."]]}]"#
        try TestSupport.writeFixture(to: dir, kjv: kjv, synodal: synodal)
        let out = dir.appendingPathComponent("bible.sqlite")
        try BibleImporter.run(rawDirectory: dir, output: out)

        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses_fts WHERE verses_fts MATCH 'cafe'", in: out) == 1)
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses_fts WHERE verses_fts MATCH 'NAIVE'", in: out) == 1)
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses_fts WHERE verses_fts MATCH 'все'", in: out) == 1)
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses_fts WHERE verses_fts MATCH 'ЕЩЕ'", in: out) == 1)
    }

    // @trace FR-3
    @Test func testMissingFileFailsWithoutOutput() throws {
        let dir = try TestSupport.tempDirectory()
        try TestSupport.writeFixture(to: dir, synodal: "")
        let out = dir.appendingPathComponent("bible.sqlite")

        #expect(throws: ImportError.missingFile("ru_synodal.json")) {
            try BibleImporter.run(rawDirectory: dir, output: out)
        }
        #expect(!FileManager.default.fileExists(atPath: out.path))
        #expect(!FileManager.default.fileExists(atPath: out.path + ".tmp"))
    }

    // @trace FR-3
    @Test func testMalformedJsonFails() throws {
        let dir = try TestSupport.tempDirectory()
        try TestSupport.writeFixture(to: dir, synodal: #"{"books": 1}"#)
        let out = dir.appendingPathComponent("bible.sqlite")

        #expect(throws: ImportError.malformed("ru_synodal.json")) {
            try BibleImporter.run(rawDirectory: dir, output: out)
        }
        #expect(!FileManager.default.fileExists(atPath: out.path))
    }

    // @trace FR-1
    @Test func testReplacesExistingOutput() throws {
        let dir = try TestSupport.tempDirectory()
        try TestSupport.writeFixture(to: dir)
        let out = dir.appendingPathComponent("bible.sqlite")
        try BibleImporter.run(rawDirectory: dir, output: out)
        try BibleImporter.run(rawDirectory: dir, output: out)

        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses", in: out) == 16)
    }

    // @trace FR-28
    @Test func testEmptyVerseIsSkippedWithoutShift() throws {
        let dir = try TestSupport.tempDirectory()
        let ohienko = #"[{"abbrev":"19","name":"Psalms","chapters":[["", "Господи, як багато моїх ворогів"]]}]"#
        try TestSupport.writeFixture(to: dir, ohienko: ohienko)
        let out = dir.appendingPathComponent("bible.sqlite")
        try BibleImporter.run(rawDirectory: dir, output: out)

        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses WHERE translation = 'ohienko' AND verse = 1", in: out) == 0)
        #expect(try TestSupport.string("SELECT text FROM verses WHERE translation = 'ohienko' AND verse = 2", in: out) == "Господи, як багато моїх ворогів")
    }

    // @trace FR-29
    @Test func testImportsFourTranslations() throws {
        let dir = try TestSupport.tempDirectory()
        try TestSupport.writeFixture(to: dir)
        let out = dir.appendingPathComponent("bible.sqlite")
        try BibleImporter.run(rawDirectory: dir, output: out)
        #expect(try TestSupport.count("SELECT COUNT(DISTINCT translation) FROM verses", in: out) == 4)
        // Czech diacritics are folded: «buh» finds «Bůh».
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses_fts WHERE verses_fts MATCH 'buh'", in: out) == 1)
    }
}
