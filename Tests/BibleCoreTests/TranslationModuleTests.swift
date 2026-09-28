import Foundation
import Testing
@testable import BibleCore

@Suite struct TranslationModuleTests {
    // @trace FR-30
    @Test func testBuiltInCatalogComesFromManifest() throws {
        let manifest = try TranslationCatalog.load(from: TranslationCatalog.bundledManifest)
        #expect(manifest.map(\.rawValue) == ["kjv", "bkr", "ohienko", "synodal"])
        #expect(Translation.allCases == manifest)
        #expect(Translation.synodal.numbering == .synodal)
        #expect(Translation.kjv.numbering == .kjv)
    }

    /// Новий переклад існуючою мовою: лише рядок маніфесту.
    static let webModule = """
    [{"code": "web", "title": "WEB", "language": "en", "languageTitle": "English", "numbering": "kjv", "file": "en_web.json"}]
    """

    /// Нова мова: маніфест дає назви й скорочення 66 книг.
    static func polishModule() -> String {
        let books = (1...66).map { #"{"name": "Księga \#($0)", "abbreviation": "Ks\#($0)"}"# }.joined(separator: ",")
        return """
        [{"code": "pl_bg", "title": "Gdańska", "language": "pl", "languageTitle": "polski", "numbering": "kjv",
          "file": "pl_bg.json", "books": [\(books)]}]
        """
    }

    // @trace FR-30
    @Test func testModuleInExistingLanguage() throws {
        let web = try #require(try TranslationCatalog.load(from: Data(Self.webModule.utf8)).first)
        #expect(web.rawValue == "web" && web.language == .english && web.menuTitle == "WEB — English")
        #expect(Book(number: 43)?.name(in: web) == "John")
        #expect(Reference(book: 43, chapter: 3, verseStart: 16).format(in: web) == "John 3:16")
        #expect(Stemmer(language: web.language).stem("loved") == Stemmer(language: .english).stem("loved"))
    }

    // @trace FR-30
    @Test func testModuleWithNewLanguageBringsBookNames() throws {
        let polish = try #require(try TranslationCatalog.load(from: Data(Self.polishModule().utf8)).first)
        #expect(polish.language == .other("pl"))
        #expect(Book(number: 43)?.name(in: polish) == "Księga 43")
        #expect(Reference(book: 43, chapter: 3, verseStart: 16).format(in: polish) == "Ks43 3:16")
        // Мова без стемера: слова лише в нижньому регістрі.
        #expect(Stemmer(language: polish.language).stem("Bóg") == "bóg")
    }

    // @trace FR-30
    @Test func testInvalidManifestsAreRejected() {
        let cases = [
            #"[{"code": "x", "title": "X", "language": "pl", "languageTitle": "polski", "numbering": "kjv", "file": "x.json"}]"#,
            #"[{"code": "x", "title": "X", "language": "en", "languageTitle": "E", "numbering": "lxx", "file": "x.json"}]"#,
            #"[{"code": "kjv", "title": "A", "language": "en", "languageTitle": "E", "numbering": "kjv", "file": "a.json"},{"code": "kjv", "title": "B", "language": "en", "languageTitle": "E", "numbering": "kjv", "file": "b.json"}]"#,
            "not json",
        ]
        for json in cases {
            #expect(throws: (any Error).self, "\(json.prefix(40))") { try TranslationCatalog.load(from: Data(json.utf8)) }
        }
    }

    // @trace FR-30
    @Test func testImportingAModuleNeedsNoCodeChange() throws {
        let dir = try TestSupport.tempDirectory()
        try TestSupport.writeFixture(to: dir)
        let web = try #require(try TranslationCatalog.load(from: Data(Self.webModule.utf8)).first)
        try Data("""
        [{"abbrev":"gn","name":"Genesis","chapters":[["In the beginning, God created the heavens and the earth.","The earth was formless."]]},
         {"abbrev":"ex","name":"Exodus","chapters":[["Now these are the names."],["A man went."]]}]
        """.utf8).write(to: dir.appendingPathComponent("en_web.json"))
        let out = dir.appendingPathComponent("bible.sqlite")
        try BibleImporter.run(rawDirectory: dir, output: out, translations: Translation.allCases + [web])
        let repository = try SQLiteBibleRepository(path: out)
        #expect(try repository.books(translation: web).map(\.number) == [1, 2])
        #expect(try repository.verses(book: 1, chapter: 1, translation: web).first?.text.hasPrefix("In the beginning, God") == true)
        #expect(try repository.search("created", translation: web).count == 1)
    }

    // @trace FR-30
    @Test func testTranslationCodesRoundTrip() throws {
        let data = try JSONEncoder().encode([Translation.kjv, .synodal])
        #expect(String(decoding: data, as: UTF8.self) == #"["kjv","synodal"]"#)
        #expect(try JSONDecoder().decode([Translation].self, from: data) == [.kjv, .synodal])
        #expect(throws: (any Error).self) { try JSONDecoder().decode(Translation.self, from: Data(#""xx""#.utf8)) }
        #expect(Translation(rawValue: "ohienko") == .ohienko)
        #expect(Translation(rawValue: "xx") == nil)
    }
}

extension TranslationModuleTests {
    // @trace FR-30
    @Test func testShortcutsOnlyForFirstNine() {
        #expect(TranslationShortcut.digit(forIndex: 0) == "1")
        #expect(TranslationShortcut.digit(forIndex: 8) == "9")
        #expect(TranslationShortcut.digit(forIndex: 9) == nil)
        #expect(TranslationShortcut.digit(forIndex: -1) == nil)
    }

    // @trace FR-30
    @Test func testRequiredBuiltInCodesInBundledManifest() throws {
        let codes = try TranslationCatalog.load(from: TranslationCatalog.bundledManifest).map(\.rawValue)
        #expect(Set(["kjv", "bkr", "ohienko", "synodal"]).isSubset(of: codes))
        // Налаштування з кодом, якого вже немає в маніфесті, губить лише цей код.
        let panels = try JSONDecoder().decode(ComparePanels.self, from: Data(#"["synodal","gone","kjv"]"#.utf8))
        #expect(panels.visible == [.synodal, .kjv])
    }
}

extension TranslationModuleTests {
    // @trace FR-30
    @Test func testIdentityAndMessages() throws {
        #expect([Language.english, .russian, .ukrainian, .czech, .other("pl")].map(\.code) == ["en", "ru", "uk", "cs", "pl"])
        #expect(Translation.kjv.id == "kjv" && "\(Translation.synodal)" == "synodal")
        let polish = try #require(try TranslationCatalog.load(from: Data(Self.polishModule().utf8)).first)
        #expect(Book.spellings(from: [polish, .kjv])[42] == ["Księga 43", "Ks43"])
        for error in [TranslationCatalog.Error.duplicateCode("a"), .missingBookNames("b"), .badBookNames("c")] {
            #expect(!"\(error)".isEmpty)
        }
    }
}
