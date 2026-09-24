import Foundation
import Testing
@testable import BibleCore

@Suite struct ImporterTests {
    @Test func testImportsFixture() throws {
        let dir = try TestSupport.tempDirectory()
        try TestSupport.writeFixture(to: dir)
        let out = dir.appendingPathComponent("bible.sqlite")
        try BibleImporter.run(rawDirectory: dir, output: out)

        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses", in: out) == 8)
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses WHERE translation = 'kjv' AND book = 2 AND chapter = 2 AND verse = 1", in: out) == 1)
        #expect(try TestSupport.string("SELECT text FROM verses WHERE translation = 'synodal' AND book = 1 AND chapter = 1 AND verse = 1", in: out) == "В начале сотворил Бог небо и землю.")
    }

    @Test func testStripsMarkup() throws {
        let dir = try TestSupport.tempDirectory()
        let kjv = "\u{FEFF}" + #"[{"abbrev":"gn","name":"Genesis","chapters":[["And the earth was {without} form."]]}]"#
        try TestSupport.writeFixture(to: dir, kjv: kjv)
        let out = dir.appendingPathComponent("bible.sqlite")
        try BibleImporter.run(rawDirectory: dir, output: out)

        #expect(try TestSupport.string("SELECT text FROM verses WHERE translation = 'kjv'", in: out) == "And the earth was without form.")
    }

    @Test func testFtsRowCountMatchesVerses() throws {
        let dir = try TestSupport.tempDirectory()
        try TestSupport.writeFixture(to: dir)
        let out = dir.appendingPathComponent("bible.sqlite")
        try BibleImporter.run(rawDirectory: dir, output: out)

        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses_fts", in: out) == 8)
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses_fts WHERE verses_fts MATCH 'НАЧАЛЕ'", in: out) == 1)
    }

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

    @Test func testMalformedJsonFails() throws {
        let dir = try TestSupport.tempDirectory()
        try TestSupport.writeFixture(to: dir, synodal: #"{"books": 1}"#)
        let out = dir.appendingPathComponent("bible.sqlite")

        #expect(throws: ImportError.malformed("ru_synodal.json")) {
            try BibleImporter.run(rawDirectory: dir, output: out)
        }
        #expect(!FileManager.default.fileExists(atPath: out.path))
    }

    @Test func testReplacesExistingOutput() throws {
        let dir = try TestSupport.tempDirectory()
        try TestSupport.writeFixture(to: dir)
        let out = dir.appendingPathComponent("bible.sqlite")
        try BibleImporter.run(rawDirectory: dir, output: out)
        try BibleImporter.run(rawDirectory: dir, output: out)

        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses", in: out) == 8)
    }
}
