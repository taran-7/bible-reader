import AppKit
import Carbon.HIToolbox
import XCTest

/// NFR-3 (launch < 1 s) and NFR-4 (VoiceOver, keyboard): the real app, no mouse.
@MainActor
final class AccessibilityUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-ResetReadingPreferences", "YES"]
        app.launchEnvironment = ["BIBLE_READER_PROFILE": UUID().uuidString]
    }

    override func tearDown() async throws {
        app.terminate()
    }

    private func launch() {
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
    }

    /// The physical key's character in the current layout, so the test does not depend on it.
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

    private func expectTitle(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.matching(NSPredicate(format: "title == %@", title)).firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "вікно «\(title)»", file: file, line: line)
    }

    /// The number from the `launch-time` element; re-read until the text appears (the element is empty for a moment).
    private func launchMilliseconds() -> Int {
        let report = app.staticTexts["launch-time"]
        XCTAssertTrue(report.waitForExistence(timeout: 10))
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            let text = (report.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? report.label
            if let milliseconds = Int(text.filter(\.isNumber)) { return milliseconds }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("launch-time без числа: value «\(report.value ?? "")», label «\(report.label)»")
        return .max
    }

    // @trace NFR-3
    func testLaunchUnderOneSecond() {
        // NFR-3 is a warm launch: the first one warms the disk cache (its number is only recorded), the second is checked.
        launch()
        let cold = launchMilliseconds()
        app.terminate()
        launch()
        let milliseconds = launchMilliseconds()
        // The number is recorded only after verses are shown, not the database error screen.
        XCTAssertTrue(app.descendants(matching: .any)["verse-1"].firstMatch.exists)
        let attachment = XCTAttachment(string: "launch: first \(cold) ms, second \(milliseconds) ms")
        attachment.lifetime = .keepAlways
        add(attachment)
        // NFR-3: 1000 ms on a Mac; CI passes a larger limit for its VM (PD-14, TEST_RUNNER_BIBLE_LAUNCH_BUDGET_MS).
        let budget = ProcessInfo.processInfo.environment["BIBLE_LAUNCH_BUDGET_MS"].flatMap(Int.init) ?? 1000
        XCTAssertLessThan(milliseconds, budget, "запуск \(milliseconds) мс, межа \(budget) мс")
    }

    // @trace NFR-4
    func testVoiceOverLabels() {
        launch()
        let verse = app.descendants(matching: .any)["verse-1"].firstMatch
        XCTAssertTrue(verse.waitForExistence(timeout: 5))
        // VoiceOver reads the verse number and text.
        XCTAssertTrue(verse.label.hasPrefix("1 In the beginning God created"), verse.label)
        // Toolbar buttons have names, not just icons.
        for id in ["bookmark-chapter", "translation"] {
            let element = app.descendants(matching: .any)[id].firstMatch
            XCTAssertTrue(element.waitForExistence(timeout: 5), id)
            // A menu button on newer macOS gives its name in AXTitle, not AXDescription; VoiceOver reads both.
            XCTAssertFalse(element.label.isEmpty && element.title.isEmpty, id)
        }
        XCTAssertTrue(app.buttons["Наступний розділ"].exists)
        XCTAssertTrue(app.buttons["Попередній розділ"].exists)
    }

    // @trace NFR-4
    func testKeyboardOnlyReading() {
        launch()
        expectTitle("Genesis 1")
        // ⌘F → the search field, a reference from the keyboard, Return.
        let field = app.searchFields.firstMatch
        app.typeKey(physicalKey(kVK_ANSI_F, fallback: "f"), modifierFlags: .command)
        wait(for: [expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)], timeout: 5)
        // Pasting with ⌘V, not typing: in a Cyrillic layout XCUI does not synthesize Latin.
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("John 3:16", forType: .string)
        app.typeKey(physicalKey(kVK_ANSI_V, fallback: "v"), modifierFlags: .command)
        app.typeKey(.return, modifierFlags: [])
        expectTitle("John 3")
        // After jumping to a reference, focus goes to the verse list: ↓ selects the next one, ⌘C copies the quote.
        wait(for: [expectation(for: NSPredicate(format: "hasKeyboardFocus == false"), evaluatedWith: field)], timeout: 5)
        app.typeKey(.downArrow, modifierFlags: [])
        let saved = NSPasteboard.general.string(forType: .string)
        let before = NSPasteboard.general.changeCount
        app.typeKey(physicalKey(kVK_ANSI_C, fallback: "c"), modifierFlags: .command)
        let deadline = Date().addingTimeInterval(5)
        while NSPasteboard.general.changeCount == before, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        let copied = NSPasteboard.general.string(forType: .string)
        // Restore the developer's clipboard.
        NSPasteboard.general.clearContents()
        if let saved { NSPasteboard.general.setString(saved, forType: .string) }
        XCTAssertTrue(copied?.contains("(John 3:17)") == true, copied ?? "буфер порожній")
        // ⌘D is a chapter bookmark; ⌘] / ⌘[ are chapters; ⌘⌥3 is Ohienko.
        app.typeKey(physicalKey(kVK_ANSI_D, fallback: "d"), modifierFlags: .command)
        XCTAssertTrue(app.descendants(matching: .any)["bookmark-row"].firstMatch.waitForExistence(timeout: 5))
        app.typeKey(physicalKey(kVK_ANSI_RightBracket, fallback: "]"), modifierFlags: .command)
        expectTitle("John 4")
        app.typeKey(physicalKey(kVK_ANSI_LeftBracket, fallback: "["), modifierFlags: .command)
        expectTitle("John 3")
        // The digit row is the same in Latin and Cyrillic layouts (on Czech, tech debt #23).
        app.typeKey("3", modifierFlags: [.command, .option])
        expectTitle("Від Івана 3")
    }
}
