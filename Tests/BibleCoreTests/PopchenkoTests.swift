import Foundation
import Testing
@testable import BibleCore

/// FR-43: the optional New Testament-only module «Попченко Ю.». The text itself is never in the repository,
/// so these tests use synthetic fixtures and the manifest metadata.
@Suite struct PopchenkoModuleTests {
    /// A New Testament-only module like the real one: 27 books and `coverage: nt`.
    static func ntModule(optional: Bool = true, books: Int = 27) -> String {
        let names = (0..<books).map { #"{"name": "Книга \#($0 + 40)", "abbreviation": "К\#($0 + 40)"}"# }.joined(separator: ",")
        return """
        [{"code": "nt_test", "title": "NT", "language": "uk", "languageTitle": "українська", "numbering": "kjv",
          "file": "uk_nt_test.json", "coverage": "nt", "optional": \(optional), "books": [\(names)]}]
        """
    }

    static func loadNT() throws -> Translation {
        try #require(try TranslationCatalog.load(from: Data(ntModule().utf8)).first)
    }

    // @trace FR-43
    @Test func testBundledManifestHasOptionalNewTestamentModule() throws {
        let popchenko = try #require(Translation(rawValue: "popchenko"))
        #expect(popchenko == Translation.popchenko)
        #expect(popchenko.title == "Попченко Ю." && popchenko.language == .ukrainian)
        #expect(popchenko.menuTitle == "Попченко Ю. — українська")
        #expect(popchenko.coverage == .nt && popchenko.isOptional)
        #expect(popchenko.sourceFileName == "uk_popchenko.json")
        #expect(popchenko.books?.count == 27)
        // Every built-in translation keeps the whole Bible and is required.
        for translation in Translation.allCases where translation != .popchenko {
            #expect(translation.coverage == .bible && !translation.isOptional)
        }
    }

    // @trace FR-43
    @Test func testCoveredBooks() throws {
        #expect(Translation.popchenko.covers(book: 39) == false)
        #expect(Translation.popchenko.covers(book: 40) && Translation.popchenko.covers(book: 66))
        #expect(Translation.kjv.covers(book: 1) && Translation.kjv.covers(book: 66))
        #expect(Translation.popchenko.coverage.bookRange == 40...66)
    }

    // @trace FR-43
    @Test func testOwnBookNamesFromThePrintedEdition() throws {
        let p = Translation.popchenko
        func name(_ n: Int) -> String? { Book(number: n)?.name(in: p) }
        func abbr(_ n: Int) -> String? { Book(number: n)?.abbreviation(in: p) }
        #expect(name(40) == "Від Матвія" && abbr(40) == "Мт")
        #expect(name(43) == "Від Іоана" && abbr(43) == "Ін")
        #expect(name(46) == "1 Коринфян" && abbr(46) == "1 Кор")
        #expect(name(50) == "Филип’ян")
        #expect(name(52) == "1 Фессалонікійців")
        #expect(name(65) == "Іуди" && abbr(65) == "Іуд")
        #expect(name(66) == "Одкровення" && abbr(66) == "Одк")
        // Old Testament books are not in the module: the Ukrainian built-in names are the fallback (Compare titles).
        #expect(name(1) == Book(number: 1)?.ukrainianName)
        #expect(Reference(book: 66, chapter: 22, verseStart: 21).format(in: p) == "Одк. 22:21")
    }

    // @trace FR-43
    @Test func testPopchenkoAbbreviationsAreParsedAsReferences() {
        #expect(Reference.parse("Одк 22:21") == Reference(book: 66, chapter: 22, verseStart: 21))
        #expect(Reference.parse("Ін. 3:16") == Reference(book: 43, chapter: 3, verseStart: 16))
        #expect(Reference.parse("1 Коринфян 13") == Reference(book: 46, chapter: 13))
        #expect(Reference.parse("Одкровення 1:1") == Reference(book: 66, chapter: 1, verseStart: 1))
        #expect(Reference.parse("Филип’ян 4:13") == Reference(book: 50, chapter: 4, verseStart: 13))
        // Other translations' spellings still resolve to the same books.
        #expect(Reference.parse("Ів. 3:16")?.book == 43)
    }

    // @trace FR-43
    @Test func testManifestChecksCoverageAndBookCount() throws {
        let nt = try Self.loadNT()
        #expect(nt.coverage == .nt && nt.isOptional && nt.books?.count == 27)
        #expect(throws: TranslationCatalog.Error.badBookNames("nt_test")) {
            try TranslationCatalog.load(from: Data(Self.ntModule(books: 66).utf8))
        }
        let unknown = Self.ntModule().replacingOccurrences(of: #""nt""#, with: #""psalms""#)
        #expect(throws: (any Error).self) { try TranslationCatalog.load(from: Data(unknown.utf8)) }
        // Without the fields a module is a required whole Bible.
        let web = try #require(try TranslationCatalog.load(from: Data(TranslationModuleTests.webModule.utf8)).first)
        #expect(web.coverage == .bible && !web.isOptional)
    }

    // @trace FR-43
    @Test func testSpellingsOfAnNTModuleAreIndexedByBookNumber() throws {
        let nt = try Self.loadNT()
        let spellings = Book.spellings(from: [nt])
        #expect(spellings[0].isEmpty)
        #expect(spellings[39] == ["Книга 40", "К40"])
        #expect(spellings[65] == ["Книга 66", "К66"])
    }
}

@Suite struct PopchenkoImportTests {
    static let ntFile = """
    [{"abbrev":"40","name":"Matthew","chapters":[["Родовід Ісуса.","Авраам породив Ісаака."],["Коли ж народився Ісус."]]},
     {"abbrev":"41","name":"Mark","chapters":[["Початок Євангелія."]]}]
    """

    // @trace FR-43
    @Test func testMissingOptionalFileIsSkipped() throws {
        let dir = try TestSupport.tempDirectory()
        try TestSupport.writeFixture(to: dir)
        let out = dir.appendingPathComponent("bible.sqlite")
        // The bundled catalog includes the optional Popchenko, but its file is absent: the build still succeeds.
        try BibleImporter.run(rawDirectory: dir, output: out)
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses WHERE translation = 'popchenko'", in: out) == 0)
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses", in: out) == 16)
    }

    // @trace FR-43
    @Test func testMissingRequiredFileStillFails() throws {
        let dir = try TestSupport.tempDirectory()
        try TestSupport.writeFixture(to: dir, kjv: "")
        #expect(throws: ImportError.missingFile(Translation.kjv.sourceFileName)) {
            try BibleImporter.run(rawDirectory: dir, output: dir.appendingPathComponent("bible.sqlite"))
        }
    }

    // @trace FR-43
    @Test func testNewTestamentFileLandsOnBooks40Plus() throws {
        let dir = try TestSupport.tempDirectory()
        let nt = try PopchenkoModuleTests.loadNT()
        try Data(Self.ntFile.utf8).write(to: dir.appendingPathComponent(nt.sourceFileName))
        try TestSupport.writeFixture(to: dir)
        let out = dir.appendingPathComponent("bible.sqlite")
        try BibleImporter.run(rawDirectory: dir, output: out, translations: Translation.allCases + [nt])
        #expect(try TestSupport.keys(nt, in: out).map { [$0.book, $0.chapter, $0.verse] }
                == [[40, 1, 1], [40, 1, 2], [40, 2, 1], [41, 1, 1]])
        let repository = try SQLiteBibleRepository(path: out)
        #expect(try repository.books(translation: nt).map(\.number) == [40, 41])
        #expect(try repository.hasTranslation(nt))
        #expect(try repository.verses(book: 40, chapter: 1, translation: nt).first?.text == "Родовід Ісуса.")
        // The module is searchable by its own stemmer; the Old Testament scope finds nothing, without an error (FR-43).
        #expect(try repository.search("Авраам", translation: nt).count == 1)
        let page = try repository.searchPage("Авраам", translation: nt, scope: .oldTestament, offset: 0, limit: 10)
        #expect(page.results.isEmpty && page.total == 0)
        let newTestament = try repository.searchPage("Авраам", translation: nt, scope: .newTestament, offset: 0, limit: 10)
        #expect(newTestament.total == 1)
    }

    // @trace FR-43
    @Test func testTruncatedNewTestamentFileFails() throws {
        let dir = try TestSupport.tempDirectory()
        let nt = try PopchenkoModuleTests.loadNT()
        try Data(Self.ntFile.utf8).write(to: dir.appendingPathComponent(nt.sourceFileName))
        try TestSupport.writeFixture(to: dir)
        #expect(throws: ImportError.incomplete(nt.sourceFileName, books: 2, expected: 27)) {
            try BibleImporter.run(rawDirectory: dir, output: dir.appendingPathComponent("bible.sqlite"),
                                  translations: [nt], expectedBooks: 66)
        }
    }

    // @trace FR-43
    @Test func testRepositoryReportsMissingTranslation() throws {
        let dir = try TestSupport.tempDirectory()
        try TestSupport.writeFixture(to: dir)
        let out = dir.appendingPathComponent("bible.sqlite")
        try BibleImporter.run(rawDirectory: dir, output: out)
        let repository = try SQLiteBibleRepository(path: out)
        #expect(try repository.hasTranslation(.kjv))
        #expect(try repository.hasTranslation(.popchenko) == false)
    }
}

/// A repository like the real one with the Popchenko text: that translation has books 40…66 only.
final class NewTestamentRepository: BibleRepository, @unchecked Sendable {
    let hasPopchenko: Bool
    init(hasPopchenko: Bool = true) { self.hasPopchenko = hasPopchenko }

    func hasTranslation(_ translation: Translation) throws -> Bool { translation != .popchenko || hasPopchenko }
    func books(translation: Translation) throws -> [Book] {
        Book.all.filter { translation.covers(book: $0.number) }
    }
    func chapterCount(book: Int, translation: Translation) throws -> Int { translation.covers(book: book) ? 3 : 0 }
    func verses(book: Int, chapter: Int, translation: Translation) throws -> [Verse] {
        guard translation.covers(book: book) else { return [] }
        return (1...3).map { Verse(translation: translation, book: book, chapter: chapter, verse: $0, text: "\(translation.rawValue) \(book):\(chapter):\($0)") }
    }
    func searchPage(_ query: String, translation: Translation, scope: SearchScope, offset: Int, limit: Int) throws -> SearchPage { .empty }
}

@MainActor @Suite struct PopchenkoReaderTests {
    func makeModel(hasPopchenko: Bool = true, positionStore: KeyValueStore? = nil) -> ReaderViewModel {
        ReaderViewModel(positionStore: positionStore) { NewTestamentRepository(hasPopchenko: hasPopchenko) }
    }

    // @trace FR-43
    @Test func testSwitchingFromTheOldTestamentOpensMatthew1() {
        let model = makeModel()
        model.open(Location(book: 1, chapter: 2))
        model.anchorVerse = 3
        model.translation = .popchenko
        #expect(model.location == Location(book: 40, chapter: 1))
        #expect(model.verses.first?.translation == .popchenko)
        #expect(model.anchorVerse == nil)
        #expect(model.books.map(\.number) == Array(40...66))
    }

    // @trace FR-43
    @Test func testSwitchingFromTheNewTestamentKeepsThePlace() {
        let model = makeModel()
        model.open(Location(book: 43, chapter: 3), focus: 16)
        model.anchorVerse = 16
        model.translation = .popchenko
        #expect(model.location == Location(book: 43, chapter: 3))
        #expect(model.focusedVerse == 16)
        model.translation = .ohienko
        #expect(model.location == Location(book: 43, chapter: 3))
    }

    // @trace FR-43
    @Test func testReferenceToAnOldTestamentBookDoesNotOpenAnEmptyChapter() {
        let model = makeModel()
        model.translation = .popchenko
        model.query = "Буття 1"
        model.submitSearch()
        #expect(model.location == Location(book: 40, chapter: 1))
        #expect(model.verses.isEmpty == false)
        model.query = "Одк 2:3"
        model.submitSearch()
        #expect(model.location == Location(book: 66, chapter: 2))
    }

    // @trace FR-43
    @Test func testOpeningABookOutsideTheTranslationDoesNothing() {
        let model = makeModel()
        model.translation = .popchenko
        model.open(Location(book: 19, chapter: 23), focus: 1)
        #expect(model.location == Location(book: 40, chapter: 1))
        #expect(model.verses.isEmpty == false)
    }

    // @trace FR-43
    @Test func testUnavailableOptionalTranslationIsHidden() {
        #expect(makeModel().availableTranslations == Translation.allCases)
        let without = makeModel(hasPopchenko: false)
        #expect(without.availableTranslations == Translation.allCases.filter { $0 != .popchenko })
    }

    // @trace FR-43
    @Test func testSavedPositionInAMissingTranslationIsIgnored() throws {
        let store = DictionaryStore()
        let position = ReaderViewModel.Position(translation: .popchenko, book: 43, chapter: 3)
        store.set(try JSONEncoder().encode(position), forKey: ReaderViewModel.positionKey)
        #expect(makeModel(hasPopchenko: true, positionStore: store).translation == .popchenko)
        let model = makeModel(hasPopchenko: false, positionStore: store)
        #expect(model.translation == .kjv)
        #expect(model.location == Location(book: 1, chapter: 1))
    }

    // @trace FR-43
    @Test func testCompareSkipsUnavailableTranslations() {
        let model = makeModel(hasPopchenko: false)
        model.showComparison(of: [1], with: [.popchenko, .ohienko])
        #expect(model.comparison?.translations == [.kjv, .ohienko])
    }

    // @trace FR-43
    @Test func testCompareShowsAnEmptyCellForOldTestamentVerses() {
        let model = makeModel()
        model.open(Location(book: 1, chapter: 1))
        model.showComparison(of: [1], with: [.popchenko, .ohienko])
        let row = model.comparison?.rows.first
        #expect(row?.others.first?.isEmpty == true)
        #expect(row?.others.last?.isEmpty == false)
        #expect(model.comparison?.isMissing(.popchenko) == true)
        #expect(model.comparison?.isMissing(.ohienko) == false)
    }
}

/// Runs only on a Mac that fetched the text with `scripts/fetch_ppch.sh`; CI has no such file and skips it.
@Suite struct PopchenkoLocalTextTests {
    static let hasText = FileManager.default.fileExists(
        atPath: TestSupport.rawData.appendingPathComponent(Translation.popchenko.sourceFileName).path)

    // @trace FR-43
    @Test(.enabled(if: PopchenkoLocalTextTests.hasText)) func testRealTextNumberingAndPrintFixes() throws {
        let db = try TestSupport.tempDirectory().appendingPathComponent("bible.sqlite")
        try BibleImporter.run(rawDirectory: TestSupport.rawData, output: db)
        func text(_ book: Int, _ chapter: Int, _ verse: Int) throws -> String {
            try TestSupport.string("SELECT text FROM verses WHERE translation = 'popchenko' AND book = \(book) AND chapter = \(chapter) AND verse = \(verse)", in: db) ?? ""
        }
        #expect(try TestSupport.count("SELECT COUNT(DISTINCT book) FROM verses WHERE translation = 'popchenko'", in: db) == 27)
        // As many verses as the KJV New Testament, chapter by chapter.
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses WHERE translation = 'popchenko'", in: db)
                == TestSupport.count("SELECT COUNT(*) FROM verses WHERE translation = 'kjv' AND book >= 40", in: db))
        #expect(try TestSupport.count("""
            SELECT COUNT(*) FROM (SELECT book, chapter, COUNT(*) n FROM verses WHERE translation = 'popchenko' GROUP BY 1, 2) p
            JOIN (SELECT book, chapter, COUNT(*) n FROM verses WHERE translation = 'kjv' GROUP BY 1, 2) k USING (book, chapter)
            WHERE p.n != k.n
            """, in: db) == 0)
        #expect(try text(43, 3, 16).hasPrefix("Бо так полюбив Бог світ"))
        // Print fixes: 2 Tim 2:15 without the source typo, Rev 22:21 patched in.
        #expect(try text(55, 2, 15).contains("якому нічого соромитись"))
        #expect(try text(66, 22, 21) == "Благодать нашого Господа Ісуса Христа хай буде з усіма вами! Амінь.")
        // Eph 2:22: the source had a stray footnote number «На15 Якому».
        #expect(try text(49, 2, 22).hasPrefix("На Якому і ви разом"))
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses WHERE translation = 'popchenko' AND text GLOB '*[а-яіїєґА-ЯІЇЄҐ][0-9]*'", in: db) == 0)
        #expect(try TestSupport.count("SELECT COUNT(*) FROM verses WHERE translation = 'popchenko' AND (text LIKE '%^%' OR text = '')", in: db) == 0)
    }
}
