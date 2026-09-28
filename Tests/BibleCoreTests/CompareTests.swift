import Foundation
import Testing
@testable import BibleCore

@Suite struct ComparePanelsTests {
    // @trace FR-36
    @Test func testDefaultShowsAllTranslationsInMenuOrder() {
        let panels = ComparePanels()
        #expect(panels.visible == Translation.allCases)
    }

    // @trace FR-36
    @Test func testCloseAndRestore() {
        var panels = ComparePanels()
        panels.close(.bkr)
        #expect(panels.visible == [.kjv, .ohienko, .synodal])
        panels.add(.bkr)
        #expect(panels.visible == [.kjv, .ohienko, .synodal, .bkr])
        panels.add(.bkr)
        #expect(panels.visible.count == 4)
        // Останню панель не закрити: вікно без перекладів не має сенсу.
        for translation in [Translation.kjv, .ohienko, .synodal] { panels.close(translation) }
        #expect(panels.visible == [.bkr])
        #expect(!panels.canClose)
        panels.close(.bkr)
        #expect(panels.visible == [.bkr])
    }

    // @trace FR-36
    @Test func testToggleKeepsOneChoice() {
        var panels = ComparePanels(visible: [.kjv, .synodal])
        panels.toggle(.bkr)
        #expect(panels.visible == [.kjv, .synodal, .bkr])
        panels.toggle(.kjv)
        panels.toggle(.synodal)
        #expect(panels.visible == [.bkr])
        panels.toggle(.bkr)
        #expect(panels.visible == [.bkr])
    }

    // @trace FR-36
    @Test func testPersistedInPreferences() throws {
        var preferences = ReadingPreferences()
        preferences.comparePanels.close(.synodal)
        let decoded = try JSONDecoder().decode(ReadingPreferences.self, from: JSONEncoder().encode(preferences))
        #expect(decoded.comparePanels.visible == [.kjv, .bkr, .ohienko])
        // Невідомі й повторені переклади відкидаємо; порожній список — стандартний.
        let odd = try JSONDecoder().decode(ReadingPreferences.self, from: Data(#"{"comparePanels":["kjv","xx","kjv","bkr"]}"#.utf8))
        #expect(odd.comparePanels.visible == [.kjv, .bkr])
        let empty = try JSONDecoder().decode(ReadingPreferences.self, from: Data(#"{"comparePanels":[]}"#.utf8))
        #expect(empty.comparePanels.visible == Translation.allCases)
        let old = try JSONDecoder().decode(ReadingPreferences.self, from: Data(#"{"verseFontSize":20}"#.utf8))
        #expect(old.comparePanels == ComparePanels())
    }
}

@MainActor @Suite struct ComparisonTests {
    func makeModel() -> ReaderViewModel {
        ReaderViewModel { try SQLiteBibleRepository(path: TestSupport.realDatabase) }
    }

    // @trace FR-36
    @Test func testWholeChapterInColumnsAlignedByVerse() throws {
        let model = makeModel()
        model.open(Location(book: 19, chapter: 22))
        // Переклад на екрані — перша колонка, навіть якщо його вибрано ще раз.
        model.showComparison(of: [3, 1], with: [.synodal, .kjv, .ohienko])
        let comparison = try #require(model.comparison)
        #expect(comparison.translations == [.kjv, .synodal, .ohienko])
        #expect(comparison.rows.count == model.verses.count)
        #expect(comparison.highlighted == [1, 3])
        // Пс 22:1 KJV — надпис і Пс 21:2 Синодального; Огієнко — вірш у вірш.
        #expect(comparison.rows[0].others[0].map { "\($0.chapter):\($0.verse)" } == ["21:1", "21:2"])
        #expect(comparison.rows[0].others[1].map(\.verse) == [1])
        #expect(comparison.title(of: .synodal) == "Псалтирь 22")
        #expect(comparison.title(of: .ohienko).hasPrefix("Псал"))
        #expect(comparison.title(of: .kjv) == "Psalms 22")
        model.closeComparison()
        #expect(model.comparison == nil)
    }

    // @trace FR-36
    @Test func testNothingSelectedOrNavigatedAway() {
        let model = makeModel()
        model.open(Location(book: 43, chapter: 3))
        model.showComparison(of: [], with: [.synodal])
        #expect(model.comparison == nil)
        model.showComparison(of: [16], with: [.synodal])
        #expect(model.comparison?.rows.first?.id == 1)
        // Інший розділ — порівняння закривається.
        model.goNext()
        #expect(model.comparison == nil)
        #expect(ReaderViewModel { throw FakeRepository.Boom() }.comparison == nil)
        let broken = ReaderViewModel { throw FakeRepository.Boom() }
        broken.showComparison(of: [1], with: [.kjv])
        #expect(broken.comparison == nil)
    }

    // @trace FR-36
    @Test func testUnknownBookFallsBackToNumber() {
        #expect(Reference.bookLabel(99, in: .kjv) == "99")
        #expect(Quote.format([Verse(translation: .kjv, book: 99, chapter: 1, verse: 1, text: "x")]) == "«x» (99 1:1)")
    }

    // @trace FR-15
    @Test func testReadingColumnFitsAboutSeventyFiveCharacters() {
        #expect(ReadingPreferences.readingColumnWidth(fontSize: 15) == 600)
    }
}
