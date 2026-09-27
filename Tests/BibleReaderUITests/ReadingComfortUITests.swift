import AppKit
import Carbon.HIToolbox
import XCTest

/// UI-докази для масштабу шрифтів (FR-15): реальне меню, реальні `UserDefaults`.
@MainActor
final class ReadingComfortUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    private func launch(reset: Bool) {
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        if reset { app.launchArguments += ["-ResetReadingPreferences", "YES"] }
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
    }

    private var firstVerse: XCUIElement { app.descendants(matching: .any)["verse-1"].firstMatch }

    private func verseHeight() -> CGFloat {
        XCTAssertTrue(firstVerse.waitForExistence(timeout: 5))
        return firstVerse.frame.height
    }

    private func waitForHeight(_ predicate: @escaping (CGFloat) -> Bool, _ message: String) {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, !predicate(firstVerse.frame.height) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertTrue(predicate(firstVerse.frame.height), "\(message): \(firstVerse.frame.height)")
    }

    /// Символ фізичної клавіші в поточній розкладці, щоб тест не залежав від неї.
    private func physicalKey(_ keyCode: Int, fallback: String) -> String {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let data = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return fallback }
        let layout = unsafeBitCast(data, to: CFData.self)
        var deadKeys: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = UCKeyTranslate(
            unsafeBitCast(CFDataGetBytePtr(layout), to: UnsafePointer<UCKeyboardLayout>.self),
            UInt16(keyCode), UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
        return status == noErr && length > 0 ? String(utf16CodeUnits: chars, count: length) : fallback
    }

    // @trace FR-15
    func testVerseFontScalesAndPersists() {
        launch(reset: true)
        let standard = verseHeight()
        let book = app.staticTexts["Genesis"].firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 5))
        let bookStandard = book.frame.height

        let plus = physicalKey(kVK_ANSI_Equal, fallback: "=")
        for _ in 0..<5 { app.typeKey(plus, modifierFlags: .command) }
        waitForHeight({ $0 > standard + 3 }, "⌘+ збільшує рядок")
        // Назви книг ростуть разом із текстом віршів.
        XCTAssertGreaterThan(book.frame.height, bookStandard + 3, "⌘+ збільшує назву книги")
        let enlarged = firstVerse.frame.height

        app.terminate()
        launch(reset: false)
        XCTAssertEqual(verseHeight(), enlarged, accuracy: 1, "розмір переживає перезапуск")

        app.typeKey(physicalKey(kVK_ANSI_0, fallback: "0"), modifierFlags: .command)
        waitForHeight({ abs($0 - standard) <= 1 }, "⌘0 повертає стандарт")
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

    // @trace FR-16
    func testInterfaceScaleEnlargesSearchResults() {
        launch(reset: true)
        search("only begotten Son")
        let result = app.buttons.matching(identifier: "search-result").firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        let standard = result.frame.height

        app.typeKey(physicalKey(kVK_ANSI_Comma, fallback: ","), modifierFlags: .command)
        let picker = app.popUpButtons["interface-scale"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.click()
        app.menuItems["Дуже великий"].click()
        app.typeKey("w", modifierFlags: .command)

        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, result.frame.height < standard * 1.1 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        // Рядок має фіксовані відступи, тож росте повільніше за шрифт (×1,4 дає ~×1,16).
        XCTAssertGreaterThanOrEqual(result.frame.height, standard * 1.1, "стандарт \(standard)")
    }
}
