import Foundation
import Testing
@testable import BibleCore

@Suite struct ComparePanelsTests {
    // @trace FR-36
    @Test func testDefaultShowsAllTranslationsInMenuOrder() {
        let panels = ComparePanels()
        #expect(panels.visible == Translation.allCases)
        #expect(panels.hidden.isEmpty)
    }

    // @trace FR-36
    @Test func testCloseAndRestore() {
        var panels = ComparePanels()
        panels.close(.bkr)
        #expect(panels.visible == [.kjv, .ohienko, .synodal])
        #expect(panels.hidden == [.bkr])
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
    @Test func testMoveLeftRightAndDrop() {
        var panels = ComparePanels()
        panels.moveRight(.kjv)
        #expect(panels.visible == [.bkr, .kjv, .ohienko, .synodal])
        panels.moveLeft(.synodal)
        #expect(panels.visible == [.bkr, .kjv, .synodal, .ohienko])
        #expect(!panels.canMoveLeft(.bkr) && !panels.canMoveRight(.ohienko))
        panels.moveLeft(.bkr)
        panels.moveRight(.ohienko)
        #expect(panels.visible == [.bkr, .kjv, .synodal, .ohienko])
        // Перетягування: панель стає на місце цільової.
        panels.move(.ohienko, to: .bkr)
        #expect(panels.visible == [.ohienko, .bkr, .kjv, .synodal])
        panels.move(.ohienko, to: .synodal)
        #expect(panels.visible == [.bkr, .kjv, .synodal, .ohienko])
        panels.move(.kjv, to: .kjv)
        #expect(panels.visible == [.bkr, .kjv, .synodal, .ohienko])
    }

    // @trace FR-36
    @Test func testPersistedInPreferences() throws {
        var preferences = ReadingPreferences()
        preferences.comparePanels.close(.synodal)
        preferences.comparePanels.moveLeft(.ohienko)
        let decoded = try JSONDecoder().decode(ReadingPreferences.self, from: JSONEncoder().encode(preferences))
        #expect(decoded.comparePanels.visible == [.kjv, .ohienko, .bkr])
        // Невідомі й повторені переклади відкидаємо; порожній список — стандартний.
        let odd = try JSONDecoder().decode(ReadingPreferences.self, from: Data(#"{"comparePanels":["kjv","xx","kjv","bkr"]}"#.utf8))
        #expect(odd.comparePanels.visible == [.kjv, .bkr])
        let empty = try JSONDecoder().decode(ReadingPreferences.self, from: Data(#"{"comparePanels":[]}"#.utf8))
        #expect(empty.comparePanels.visible == Translation.allCases)
        let old = try JSONDecoder().decode(ReadingPreferences.self, from: Data(#"{"verseFontSize":20}"#.utf8))
        #expect(old.comparePanels == ComparePanels())
    }
}

@Suite struct VerseComparisonTests {
    let repository = try! SQLiteBibleRepository(path: TestSupport.realDatabase)

    // @trace FR-36
    @Test func testJohn316InFourTranslations() throws {
        let panels = try VerseComparison.load(from: repository, book: 43, chapter: 3, verses: [16], panels: ComparePanels())
        #expect(panels.map(\.translation) == Translation.allCases)
        #expect(panels.map(\.reference) == ["John 3:16", "J 3:16", "Ів. 3:16", "Ин. 3:16"])
        #expect(panels.allSatisfy { $0.verses.count == 1 })
        #expect(panels.first { $0.translation == .synodal }?.verses.first?.text.hasPrefix("Ибо так возлюбил") == true)
        #expect(panels.filter(\.numberingMayDiffer).map(\.translation) == [.synodal])
    }

    // @trace FR-36
    @Test func testPsalmAndRangeInPanelOrder() throws {
        var order = ComparePanels()
        order.moveLeft(.synodal)
        order.close(.bkr)
        let panels = try VerseComparison.load(from: repository, book: 19, chapter: 23, verses: [1, 2], panels: order)
        #expect(panels.map(\.translation) == [.kjv, .synodal, .ohienko])
        #expect(panels[0].reference == "Ps 23:1-2")
        #expect(panels[0].verses.map(\.verse) == [1, 2])
        #expect(panels[0].verses.first?.text.hasPrefix("The LORD is my shepherd") == true)
        #expect(panels.first { $0.translation == .ohienko }?.verses.first?.text.contains("Господь то мій Пастир") == true)
    }

    // @trace FR-36
    @Test func testEmptySelectionHasNoPanels() throws {
        #expect(try VerseComparison.load(from: repository, book: 1, chapter: 1, verses: [], panels: ComparePanels()).isEmpty)
    }
}

@MainActor @Suite struct CompareViewModelTests {
    // @trace FR-36
    @Test func testOpenInTranslationReloadsOnce() {
        let repository = FakeRepository()
        let model = ReaderViewModel { repository }
        model.open(Location(book: 43, chapter: 3), in: .synodal, focus: 16)
        #expect(model.translation == .synodal)
        #expect(model.location == Location(book: 43, chapter: 3))
        #expect(model.verses.first?.text.hasPrefix("synodal 43:3") == true)
        #expect(model.takeFocus() == 16)
        model.open(Location(book: 1, chapter: 2), in: .synodal, focus: nil)
        #expect(model.location == Location(book: 1, chapter: 2))
    }

    // @trace FR-36
    @Test func testCompareThroughModel() throws {
        let model = ReaderViewModel { FakeRepository() }
        let panels = try model.compare(CompareRequest(book: 43, chapter: 3, verses: [2, 9]), panels: ComparePanels())
        #expect(panels.count == 4)
        // FakeRepository має 5 віршів: 9-го немає, посилання — лише на знайдений.
        #expect(panels[0].reference == "John 3:2")
        #expect(throws: ReaderViewModel.Unavailable.self) {
            try ReaderViewModel { throw FakeRepository.Boom() }.compare(CompareRequest(book: 1, chapter: 1, verses: [1]), panels: ComparePanels())
        }
        var order = ComparePanels()
        let same = order.move(.kjv, to: .kjv)
        let moved = order.move(.kjv, to: .synodal)
        #expect(!same && moved)
        #expect("\(ReaderViewModel.Unavailable())".contains("недоступна"))
    }
}

extension ComparePanelsTests {
    // @trace FR-36
    @MainActor @Test func testHiddenPanelCannotMoveAndMissingVersesKeepReference() throws {
        var panels = ComparePanels()
        panels.close(.bkr)
        #expect(!panels.canMoveLeft(.bkr) && !panels.canMoveRight(.bkr))
        let model = ReaderViewModel { FakeRepository() }
        let loaded = try model.compare(CompareRequest(book: 43, chapter: 3, verses: [40]), panels: panels)
        // Вірша немає — лишається запитане посилання, а панель порожня.
        #expect(loaded.map(\.id) == [.kjv, .ohienko, .synodal])
        #expect(loaded[0].reference == "John 3:40" && loaded[0].verses.isEmpty)
        #expect(Quote.format([Verse(translation: .kjv, book: 99, chapter: 1, verse: 1, text: "x")]) == "«x» (99 1:1)")
    }
}
