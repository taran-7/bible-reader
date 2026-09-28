import Foundation
import Testing
@testable import BibleCore

@Suite struct VersificationTests {
    static let versification = try! Versification.load(from: SQLiteBibleRepository(path: TestSupport.realDatabase))
    var v: Versification { Self.versification }

    func syn(_ b: Int, _ c: Int, _ vs: Int) -> VerseKey? { v.synodal(fromKJV: VerseKey(book: b, chapter: c, verse: vs)) }
    func kjv(_ b: Int, _ c: Int, _ vs: Int) -> VerseKey? { v.kjv(fromSynodal: VerseKey(book: b, chapter: c, verse: vs)) }
    func key(_ b: Int, _ c: Int, _ vs: Int) -> VerseKey { VerseKey(book: b, chapter: c, verse: vs) }

    // @trace FR-27
    @Test func testPsalms() {
        // Критерій PRD 6.13: Пс 22:1 KJV = Пс 21:2 Синодального (надпис — вірш 1).
        #expect(syn(19, 22, 1) == key(19, 21, 2))
        #expect(kjv(19, 21, 2) == key(19, 22, 1))
        // Надпис без відповідника веде до першого вірша KJV.
        #expect(kjv(19, 21, 1) == key(19, 22, 1))
        #expect(syn(19, 23, 1) == key(19, 22, 1))
        #expect(syn(19, 1, 1) == key(19, 1, 1))
        // Злиті й розділені псалми.
        #expect(syn(19, 10, 1) == key(19, 9, 22))
        #expect(syn(19, 115, 1) == key(19, 113, 9))
        #expect(syn(19, 116, 9) == key(19, 114, 8))
        #expect(syn(19, 116, 10) == key(19, 115, 1))
        #expect(syn(19, 147, 12) == key(19, 147, 1))
        #expect(syn(19, 150, 6) == key(19, 150, 6))
        // Пс 151 є лише в Синодальному.
        #expect(kjv(19, 151, 1) == nil)
    }

    // @trace FR-27
    @Test func testOtherBooks() {
        #expect(syn(18, 40, 1) == key(18, 39, 31))     // Йов
        #expect(syn(18, 41, 9) == key(18, 41, 1))
        #expect(syn(27, 4, 4) == key(27, 4, 1))        // Даниїл
        #expect(syn(27, 3, 24) == key(27, 3, 91))
        #expect(kjv(27, 3, 30) == nil)                 // пісня трьох юнаків
        #expect(syn(45, 16, 25) == key(45, 14, 24))    // Римлян
        #expect(syn(32, 1, 17) == key(32, 2, 1))       // Йона
        #expect(syn(4, 12, 16) == key(4, 13, 1))       // Числа
        #expect(syn(47, 13, 14) == key(47, 13, 13))    // 2 Кор
        #expect(kjv(9, 20, 43) == key(9, 20, 42))      // 1 Сам
        #expect(syn(43, 3, 16) == key(43, 3, 16))      // звичайний вірш
    }

    // @trace FR-27
    @Test func testEveryKJVVerseMapsToAnExistingSynodalVerse() throws {
        let repository = try SQLiteBibleRepository(path: TestSupport.realDatabase)
        let synodal = Set(try TestSupport.keys(.synodal, in: TestSupport.realDatabase))
        let kjvKeys = try TestSupport.keys(.kjv, in: TestSupport.realDatabase)
        _ = repository
        var unmapped: [VerseKey] = []
        for key in kjvKeys {
            guard let target = v.synodal(fromKJV: key) else { unmapped.append(key); continue }
            #expect(synodal.contains(target), "\(key) → \(target)")
        }
        #expect(unmapped.isEmpty, "\(unmapped.prefix(5))")
        // Порядок зберігається: відображення не йде назад у межах книги.
        // Виняток — доксологія Рим 16:25–27, яка в Синодальному стоїть у 14:24–26.
        let moved = { (key: VerseKey) in key.book == 45 && key.chapter == 16 && key.verse >= 24 }
        for (a, b) in zip(kjvKeys, kjvKeys.dropFirst()) where a.book == b.book && !moved(a) && !moved(b) {
            #expect(v.synodal(fromKJV: a)! <= v.synodal(fromKJV: b)!, "\(a) \(b)")
        }
    }

    // @trace FR-27
    @Test func testSameNumberingIsIdentity() {
        let key = key(19, 23, 1)
        #expect(v.map(key, from: .kjv, to: .ohienko) == key)
        #expect(v.map(key, from: .bkr, to: .kjv) == key)
        #expect(v.map(key, from: .kjv, to: .synodal) == self.key(19, 22, 1))
        #expect(v.map(self.key(19, 22, 1), from: .synodal, to: .ohienko) == key)
    }
}

extension VersificationTests {
    // @trace FR-27
    @Test func testOnlySeptuagintAdditionsHaveNoKJVVerse() throws {
        let synodal = try TestSupport.keys(.synodal, in: TestSupport.realDatabase)
        let missing = synodal.filter { v.kjv(fromSynodal: $0) == nil }
        let chapters = Set(missing.map { "\($0.book):\($0.chapter)" })
        #expect(chapters == ["6:24", "20:4", "20:13", "20:18", "27:3", "27:13", "27:14", "19:151"], "\(chapters.sorted())")
        #expect(missing.filter { $0.book == 27 && $0.chapter == 3 }.map(\.verse) == Array(24...90))
    }
}

extension VersificationTests {
    // @trace FR-27
    @Test func testSparseCountsAndUnknownVerses() {
        // Неповні дані (інша база): відсутні лічильники дають нульовий зсув, а не падіння.
        let sparse = Versification(kjvCounts: [19: [10: 1, 115: 1, 20: 1], 1: [1: 1]], synodalCounts: [:])
        #expect(sparse.synodal(fromKJV: VerseKey(book: 19, chapter: 10, verse: 1)) == VerseKey(book: 19, chapter: 9, verse: 2))
        #expect(sparse.synodal(fromKJV: VerseKey(book: 19, chapter: 115, verse: 1)) == VerseKey(book: 19, chapter: 113, verse: 1))
        #expect(sparse.synodal(fromKJV: VerseKey(book: 19, chapter: 20, verse: 1)) == VerseKey(book: 19, chapter: 19, verse: 1))
        #expect(v.allKJV(fromSynodal: VerseKey(book: 99, chapter: 1, verse: 1)).isEmpty)
    }
}

extension ParallelTests {
    // @trace FR-26
    @Test func testEdgeCases() {
        let model = makeModel()
        model.parallelTranslation = .synodal
        #expect(model.parallelRows.first?.id == 1)
        // Невідомий вірш KJV (поза розділом) лишається своїм номером.
        model.translation = .synodal
        #expect(model.localReference(book: 1, chapter: 1, verse: 999).verseStart == 999)
        #expect(model.localReference(book: 19, chapter: 23, verse: nil).verseStart == nil)
        let empty = ReaderViewModel { FakeRepository() }
        #expect(empty.canonicalChapter.chapter == 1)
    }
}

/// Нова система нумерації з маніфесту (tech debt #25): таблиця до KJV, між системами — через KJV.
@Suite struct CustomVersificationTests {
    static let vulgate: Translation.Numbering = "vulgate"
    // Умовна «Вульгата»: Пс 10 KJV = Пс 9:22…, Мал 4 KJV = Мал 3:19….
    let table = VersificationTable(segments: [
        .init(book: 19, chapter: 10, from: 1, to: 18, localChapter: 9, localVerse: 22),
        .init(book: 39, chapter: 4, from: 1, to: 6, localChapter: 3, localVerse: 19),
    ])
    var v: Versification {
        Versification(kjvCounts: [19: [9: 20, 10: 18, 23: 6], 39: [3: 18, 4: 6]], synodalCounts: [19: [9: 39, 22: 6]],
                      custom: [Self.vulgate: table])
    }
    func key(_ b: Int, _ c: Int, _ vs: Int) -> VerseKey { VerseKey(book: b, chapter: c, verse: vs) }

    // @trace FR-30
    @Test func testCustomTableMapsToAndFromKJV() {
        #expect(v.map(key(19, 10, 1), fromNumbering: .kjv, to: Self.vulgate) == key(19, 9, 22))
        #expect(v.map(key(39, 3, 24), fromNumbering: Self.vulgate, to: .kjv) == key(39, 4, 6))
        // Вірші поза сегментами — той самий номер.
        #expect(v.map(key(19, 23, 1), fromNumbering: .kjv, to: Self.vulgate) == key(19, 23, 1))
        #expect(v.allKJV(from: Self.vulgate, key(19, 9, 22)) == [key(19, 10, 1)])
        #expect(v.allKJV(from: .kjv, key(1, 1, 1)) == [key(1, 1, 1)])
    }

    // @trace FR-30
    @Test func testTwoNonKJVSystemsGoThroughKJV() {
        // Вульгата Пс 9:22 → KJV Пс 10:1 → Синодальний Пс 9:22.
        #expect(v.map(key(19, 9, 22), fromNumbering: Self.vulgate, to: .synodal) == key(19, 9, 22))
        #expect(v.map(key(19, 22, 1), fromNumbering: .synodal, to: Self.vulgate) == key(19, 23, 1))
        // Невідома система або вірш без відповідника — nil, а не падіння.
        #expect(v.map(key(19, 10, 1), fromNumbering: .kjv, to: "lxx") == nil)
        #expect(v.map(key(99, 1, 1), fromNumbering: Self.vulgate, to: .synodal) == nil)
    }
}

extension TranslationModuleTests {
    static let vulgateModule = """
    [{"code": "vg", "title": "Vulgata", "language": "en", "languageTitle": "Latina", "numbering": "vulgate", "file": "la_vg.json",
      "versification": {"segments": [{"book": 19, "chapter": 10, "from": 1, "to": 18, "localChapter": 9, "localVerse": 22}]}},
     {"code": "vg2", "title": "Vulgata 2", "language": "en", "languageTitle": "Latina", "numbering": "vulgate", "file": "la_vg2.json"}]
    """

    // @trace FR-30
    @Test func testNewNumberingNeedsTableInManifest() throws {
        let modules = try TranslationCatalog.load(from: Data(Self.vulgateModule.utf8))
        #expect(modules.map(\.numbering) == ["vulgate", "vulgate"])
        #expect(modules[0].versificationTable?.segments.first?.merge == false)
        #expect(!modules[0].sharesKJVNumbering)
        let bare = #"[{"code": "x", "title": "X", "language": "en", "languageTitle": "E", "numbering": "lxx", "file": "x.json"}]"#
        #expect(throws: TranslationCatalog.Error.missingVersification("x")) {
            try TranslationCatalog.load(from: Data(bare.utf8))
        }
        #expect(!"\(TranslationCatalog.Error.missingVersification("x"))".isEmpty)
    }
}
