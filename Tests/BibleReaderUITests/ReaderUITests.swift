import AppKit
import Carbon.HIToolbox
import XCTest

/// UI-докази для прив'язки SwiftUI: реальний додаток і реальна база з бандла.
/// Текст вводимо вставкою, а ⌘C — фізичною клавішею C, щоб тести не залежали від розкладки.
@MainActor
final class ReaderUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Без відновлення вікон попереднього запуску: інакше вікно інколи не відкривається.
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
    }

    override func tearDown() async throws {
        app.terminate()
    }

    /// Свій профіль користувача на кожен тест: закладки й останнє місце не перетікають між тестами.
    private lazy var profile = UUID().uuidString

    private func launch(environment: [String: String] = [:]) {
        app.launchEnvironment = environment.merging(["BIBLE_READER_PROFILE": profile]) { $1 }
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
    }

    private func search(_ text: String) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        app.menuItems["selectAll:"].click()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        app.menuItems["paste:"].click()
        field.typeKey(.return, modifierFlags: [])
    }

    private func verseRow(_ verse: Int) -> XCUIElement {
        app.outlineRows.containing(.any, identifier: "verse-\(verse)").firstMatch
    }

    private func expectTitle(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.matching(NSPredicate(format: "title == %@", title)).firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "вікно «\(title)»", file: file, line: line)
    }

    private func expectSelected(_ verse: Int, file: StaticString = #filePath, line: UInt = #line) {
        let row = verseRow(verse)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "рядок вірша \(verse)", file: file, line: line)
        wait(for: [expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: row)], timeout: 5)
    }

    private func pasteboardText(timeout: TimeInterval = 5) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let text = NSPasteboard.general.string(forType: .string) { return text }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return nil
    }

    /// Символ, який фізична клавіша C дає в поточній розкладці («c» в англійській, «с» у російській).
    private func physicalCKey() -> String {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let data = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return "c" }
        let layout = unsafeBitCast(data, to: CFData.self)
        var deadKeys: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = UCKeyTranslate(
            unsafeBitCast(CFDataGetBytePtr(layout), to: UnsafePointer<UCKeyboardLayout>.self),
            UInt16(kVK_ANSI_C), UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
        return status == noErr && length > 0 ? String(utf16CodeUnits: chars, count: length) : "c"
    }

    // @trace FR-13
    func testReferenceQueryOpensVerse() {
        launch()
        search("John 3:16")
        expectTitle("John 3")
        expectSelected(16)
        // Той самий номер вірша в іншій книзі теж отримує фокус (retrofit R1).
        search("Rom 3:16")
        expectTitle("Romans 3")
        expectSelected(16)
    }

    // @trace FR-10
    func testCommandCCopiesQuote() {
        launch()
        search("John 3:16")
        expectSelected(16)
        // Фокус переходить у список асинхронно; ⌘C має йти вже туди, а не в поле пошуку.
        let focusLeftField = NSPredicate(format: "hasKeyboardFocus == false")
        wait(for: [expectation(for: focusLeftField, evaluatedWith: app.searchFields.firstMatch)], timeout: 5)
        NSPasteboard.general.clearContents()
        app.typeKey(physicalCKey(), modifierFlags: .command)
        let text = pasteboardText()
        XCTAssertTrue(text?.hasPrefix("«For God so loved the world") == true, text ?? "буфер порожній")
        XCTAssertTrue(text?.hasSuffix("(John 3:16)") == true, text ?? "буфер порожній")
    }

    // @trace FR-10
    func testContextMenuCopiesQuote() {
        launch()
        search("John 3:16")
        expectSelected(16)
        NSPasteboard.general.clearContents()
        verseRow(16).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).rightClick()
        let item = app.menuItems["Копіювати"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.click()
        let text = pasteboardText()
        XCTAssertTrue(text?.hasSuffix("(John 3:16)") == true, text ?? "буфер порожній")
    }

    // @trace FR-14
    func testClickingResultOpensVerse() {
        launch()
        search("only begotten Son")
        let result = app.buttons.matching(identifier: "search-result").firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.click()
        expectTitle("John 1")
        expectSelected(18)
    }

    // @trace FR-7
    func testMissingDatabaseShowsErrorScreen() {
        launch(environment: ["BIBLE_READER_DB": "/nonexistent/bible.sqlite"])
        XCTAssertTrue(app.descendants(matching: .any)["database-error"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.searchFields.firstMatch.exists)
    }

    // @trace FR-17
    func testCopyButtonCopiesQuote() {
        launch()
        XCTAssertTrue(verseRow(1).waitForExistence(timeout: 5))
        let button = app.buttons.matching(identifier: "copy-button").firstMatch
        XCTAssertFalse(button.exists, "без виділення кнопки немає")

        search("John 3:16")
        expectSelected(16)
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        NSPasteboard.general.clearContents()
        button.click()
        let text = pasteboardText()
        XCTAssertTrue(text?.hasPrefix("«For God so loved the world") == true, text ?? "буфер порожній")
        XCTAssertTrue(text?.hasSuffix("(John 3:16)") == true, text ?? "буфер порожній")

        let copied = NSPredicate(format: "label == 'Скопійовано'")
        wait(for: [expectation(for: copied, evaluatedWith: button)], timeout: 2)
        let restored = NSPredicate(format: "label == 'Копіювати цитату'")
        wait(for: [expectation(for: restored, evaluatedWith: button)], timeout: 4)

        // Кілька віршів: кнопка над першим, копіює весь діапазон.
        verseRow(18).coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).click()
        XCUIElement.perform(withKeyModifiers: .shift) {
            verseRow(16).coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).click()
        }
        NSPasteboard.general.clearContents()
        button.click()
        let range = pasteboardText()
        XCTAssertTrue(range?.hasSuffix("»\n(John 3:16-18)") == true, range ?? "буфер порожній")
        // Номер перед кожним віршем, кожен з нового рядка.
        XCTAssertTrue(range?.hasPrefix("«16 For God so loved") == true, range ?? "буфер порожній")
        XCTAssertTrue(range?.contains("\n17 For God sent not") == true, range ?? "буфер порожній")
        XCTAssertTrue(range?.contains("\n18 He that believeth") == true, range ?? "буфер порожній")

        search("Rom 1")
        expectTitle("Romans 1")
        XCTAssertFalse(button.waitForExistence(timeout: 1), "новий розділ без виділення — кнопки немає")
    }

    // @trace FR-28
    // @trace FR-29
    func testUkrainianAndCzechTranslations() {
        launch()
        // Тип елемента меню в тулбарі різниться між версіями macOS, тож шукаємо за ідентифікатором.
        XCTAssertTrue(app.descendants(matching: .any)["translation"].firstMatch.waitForExistence(timeout: 5))
        app.menuBars.menuBarItems["Переклад"].click()
        app.menuBars.menuItems["Огієнко — українська"].click()
        expectTitle("Буття 1")
        let firstVerse = app.descendants(matching: .any)["verse-1"].firstMatch
        XCTAssertTrue(firstVerse.waitForExistence(timeout: 5))
        wait(for: [expectation(for: NSPredicate(format: "label CONTAINS 'На початку Бог створив'"), evaluatedWith: firstVerse)], timeout: 5)

        // ⌘⌥2 — Kralická (порядок: KJV, Kralická, Огієнко, Синодальний); посилання чеською.
        app.typeKey("2", modifierFlags: [.command, .option])
        search("J 3:16")
        expectTitle("Jan 3")
        expectSelected(16)
    }

    private func foundCount() -> Int? {
        let label = app.staticTexts["search-count"]
        guard label.waitForExistence(timeout: 5) else { return nil }
        let text = (label.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? label.label
        return Int(text.filter(\.isNumber))
    }

    private func waitForCount(_ predicate: @escaping (Int) -> Bool, file: StaticString = #filePath, line: UInt = #line) -> Int? {
        let deadline = Date().addingTimeInterval(5)
        var count = foundCount()
        while count.map(predicate) != true, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            count = foundCount()
        }
        XCTAssertTrue(count.map(predicate) == true, "Знайдено: \(count.map(String.init) ?? "—")", file: file, line: line)
        return count
    }

    // @trace FR-18
    // @trace FR-19
    // @trace FR-20
    // @trace FR-21
    func testSearchScopeCountAndPhrase() {
        launch()
        search("loveth")
        // Морфологія: «loveth» знаходить і «love», і «loved» — набагато більше 100 віршів.
        guard let all = waitForCount({ $0 > 300 }) else { return }
        XCTAssertTrue(app.buttons.matching(identifier: "search-result").firstMatch.waitForExistence(timeout: 5))
        let scope = app.descendants(matching: .any)["search-scope"].firstMatch
        XCTAssertTrue(scope.waitForExistence(timeout: 5))
        scope.radioButtons["Новий Завіт"].click()
        guard let newTestament = waitForCount({ $0 > 0 && $0 < all }) else { return }
        scope.radioButtons["Старий Завіт"].click()
        _ = waitForCount({ $0 == all - newTestament })
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = "search-scope"
        attachment.lifetime = .keepAlways
        add(attachment)

        scope.radioButtons["Уся Біблія"].click()
        search("\"only begotten Son\"")
        _ = waitForCount({ $0 > 0 && $0 < 10 })
    }

    private func paste(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        app.menuItems["paste:"].click()
    }

    // @trace FR-22
    // @trace FR-23
    // @trace FR-24
    // @trace FR-25
    func testBookmarksHighlightsNotesSurviveRelaunch() {
        launch()
        search("John 3:16")
        expectTitle("John 3")
        let row = verseRow(16)
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        // Координата, а не елемент: рядок під кнопкою копіювання XCUI вважає «not hittable».
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).rightClick()
        XCTAssertTrue(app.menuItems["Підсвітити"].waitForExistence(timeout: 5))
        app.menuItems["Підсвітити"].hover()
        app.menuItems["Жовтий"].click()
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).rightClick()
        app.menuItems["Додати закладку на вірш 16"].click()
        XCTAssertTrue(app.descendants(matching: .any)["bookmark-mark-16"].waitForExistence(timeout: 5))

        row.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).rightClick()
        app.menuItems["Додати нотатку…"].click()
        let editor = app.textViews["note-text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.click()
        paste("Центральний вірш")
        app.buttons["note-save"].click()
        XCTAssertTrue(app.descendants(matching: .any)["note-mark-16"].waitForExistence(timeout: 5))

        // ⌘D — закладка на розділ; обидві закладки в бічній панелі.
        app.buttons["bookmark-chapter"].click()
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "bookmark-row").count, 2)

        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = "notes-bookmarks"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Перезапуск з тим самим профілем: те саме місце, позначки й нотатка на місці.
        app.terminate()
        launch()
        expectTitle("John 3")
        XCTAssertTrue(app.descendants(matching: .any)["note-mark-16"].waitForExistence(timeout: 5))
        wait(for: [expectation(for: NSPredicate(format: "value CONTAINS 'жовтий'"), evaluatedWith: app.descendants(matching: .any)["verse-16"].firstMatch)], timeout: 5)

        // Пошук знаходить нотатку; клік відкриває вірш.
        search("Genesis 1")
        expectTitle("Genesis 1")
        search("центральний")
        let note = app.buttons.matching(identifier: "note-result").firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.click()
        expectTitle("John 3")
        expectSelected(16)
    }
}
