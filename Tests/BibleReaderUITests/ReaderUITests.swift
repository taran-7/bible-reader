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

    private func launch(environment: [String: String] = [:]) {
        app.launchEnvironment = environment
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
}
