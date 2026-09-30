import AppKit
import Carbon.HIToolbox
import XCTest

/// UI evidence for the SwiftUI wiring: the real app and the real database from the bundle.
/// Text is entered by pasting, and ⌘C with the physical C key, so tests do not depend on the layout.
@MainActor
final class ReaderUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // No restoring windows from the previous launch: otherwise the window sometimes does not open.
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
    }

    override func tearDown() async throws {
        app.terminate()
    }

    /// A separate user profile per test: bookmarks and the last position do not leak between tests.
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

    /// The character the physical C key gives in the current layout ("c" in English, "с" in Russian).
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
        // The same verse number in another book also gets focus (retrofit R1).
        search("Rom 3:16")
        expectTitle("Romans 3")
        expectSelected(16)
    }

    // @trace FR-10
    func testCommandCCopiesQuote() {
        launch()
        search("John 3:16")
        expectSelected(16)
        // Focus moves to the list asynchronously; ⌘C must already go there, not to the search field.
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
        guard let single = app.visibleButton("copy-button") else { return XCTFail("кнопки копіювання не видно") }
        single.click()
        let text = pasteboardText()
        XCTAssertTrue(text?.hasPrefix("«For God so loved the world") == true, text ?? "буфер порожній")
        XCTAssertTrue(text?.hasSuffix("(John 3:16)") == true, text ?? "буфер порожній")

        let copied = NSPredicate(format: "label == 'Скопійовано'")
        wait(for: [expectation(for: copied, evaluatedWith: button)], timeout: 2)
        let restored = NSPredicate(format: "label == 'Копіювати цитату'")
        wait(for: [expectation(for: restored, evaluatedWith: button)], timeout: 4)

        // Several verses: the button above the first, copies the whole range.
        // A range from the keyboard: row 18 is sometimes below the window's bottom edge, and a click on it gets lost.
        verseRow(16).coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).click()
        expectSelected(16)
        app.typeKey(.downArrow, modifierFlags: .shift)
        app.typeKey(.downArrow, modifierFlags: .shift)
        expectSelected(18)
        expectSelected(17)
        NSPasteboard.general.clearContents()
        guard let visible = app.visibleButton("copy-button") else { return XCTFail("кнопки копіювання не видно") }
        visible.click()
        let range = pasteboardText()
        XCTAssertTrue(range?.hasSuffix("»\n(John 3:16-18)") == true, range ?? "буфер порожній")
        // A number before each verse, each on a new line.
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
        // The toolbar menu element type differs between macOS versions, so we search by identifier.
        XCTAssertTrue(app.descendants(matching: .any)["translation"].firstMatch.waitForExistence(timeout: 5))
        app.menuBars.menuBarItems["Переклад"].click()
        app.menuBars.menuItems["Огієнко — українська"].click()
        expectTitle("Буття 1")
        let firstVerse = app.descendants(matching: .any)["verse-1"].firstMatch
        XCTAssertTrue(firstVerse.waitForExistence(timeout: 5))
        wait(for: [expectation(for: NSPredicate(format: "label CONTAINS 'На початку Бог створив'"), evaluatedWith: firstVerse)], timeout: 5)

        // ⌘⌥2 is Kralická (order: KJV, Kralická, Ohienko, Synodal); the reference is in Czech.
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
        // Morphology: "loveth" finds both "love" and "loved": far more than 100 verses.
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

    /// VoiceOver reads the verse marks (highlight, bookmark, note) at the end of the row label.
    private func expectMarks(_ verse: Int, contain text: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = app.descendants(matching: .any)["verse-\(verse)"].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 5), .completed,
                       "вірш \(verse): «\(text)» у «\(element.label)»", file: file, line: line)
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

        // A coordinate, not the element: XCUI considers the row under the copy button "not hittable".
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).rightClick()
        XCTAssertTrue(app.menuItems["Підсвітити"].waitForExistence(timeout: 5))
        app.menuItems["Підсвітити"].hover()
        app.menuItems["Жовтий"].click()
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).rightClick()
        app.menuItems["Додати закладку на вірш 16"].click()
        expectMarks(16, contain: "закладка")

        row.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).rightClick()
        app.menuItems["Додати нотатку…"].click()
        let editor = app.textViews["note-text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.click()
        paste("Центральний вірш")
        app.buttons["note-save"].click()
        expectMarks(16, contain: "є нотатка")

        // ⌘D is a chapter bookmark; both bookmarks are in the sidebar.
        app.buttons.matching(identifier: "bookmark-chapter").firstMatch.click()
        let rows = app.buttons.matching(identifier: "bookmark-row")
        XCTAssertTrue(rows.element(boundBy: 1).waitForExistence(timeout: 5), "дві закладки в бічній панелі")

        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = "notes-bookmarks"
        attachment.lifetime = .keepAlways
        add(attachment)

        // A restart with the same profile: the same position, marks and note in place.
        app.terminate()
        launch()
        expectTitle("John 3")
        expectMarks(16, contain: "є нотатка")
        expectMarks(16, contain: "жовтий")

        // Search finds the note; a click opens the verse.
        search("Genesis 1")
        expectTitle("Genesis 1")
        search("центральний")
        let note = app.buttons.matching(identifier: "note-result").firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.click()
        expectTitle("John 3")
        expectSelected(16)
    }

    // @trace FR-37
    func testBookClickShowsChapterPicker() {
        launch()
        expectTitle("Genesis 1")
        XCTAssertFalse(app.popUpButtons["Розділ"].exists, "вибору розділу в тулбарі більше немає")
        #if compiler(>=6.2)
        // The search field in the toolbar center, not on the right (only with an SDK that has .toolbarPrincipal).
        let field = app.searchFields.firstMatch
        let window = app.windows.firstMatch.frame
        XCTAssertEqual(field.frame.midX, window.midX, accuracy: window.width * 0.15, "пошук по центру")
        #endif
        let picker = app.descendants(matching: .any)["chapter-picker"].firstMatch
        app.descendants(matching: .any)["book-8"].firstMatch.click()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        // The current chapter's text stays under the window.
        expectTitle("Genesis 1")
        XCTAssertTrue(verseRow(1).exists)
        app.buttons["chapter-4"].click()
        expectTitle("Ruth 4")
        XCTAssertFalse(picker.exists)
        // Esc closes the window without navigating; the current chapter is marked.
        app.descendants(matching: .any)["book-8"].firstMatch.click()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["chapter-4"].label, "Розділ 4, поточний")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(picker.waitForNonExistence(timeout: 5))
        expectTitle("Ruth 4")
        // Keyboard (NFR-4): the cursor is on the current chapter, ← and Return open the previous one.
        app.descendants(matching: .any)["book-8"].firstMatch.click()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        // The cursor appears when the grid gets focus.
        let grid = app.descendants(matching: .any).matching(NSPredicate(format: "hasKeyboardFocus == true")).firstMatch
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        app.typeKey(.leftArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        expectTitle("Ruth 3")
        XCTAssertTrue(picker.waitForNonExistence(timeout: 5))
    }

    /// A window screenshot for review (QA_SHOTS_DIR); without the variable, only an attachment to the test result.
    private func shot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()  // the whole screen: the popover goes beyond the window
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["QA_SHOTS_DIR"] {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    // @trace FR-37
    func testPsalmsPickerAndTitleDropdown() {
        launch()
        expectTitle("Genesis 1")
        // The largest book: 150 chapters in the window beside "Psalms", scrolling inside.
        let picker = app.descendants(matching: .any)["chapter-picker"].firstMatch
        app.descendants(matching: .any)["book-19"].firstMatch.click()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let book = app.descendants(matching: .any)["book-19"].firstMatch
        XCTAssertGreaterThan(picker.frame.minX, book.frame.minX, "вікно праворуч від книги")
        XCTAssertTrue(app.buttons["chapter-1"].exists)
        shot("psalms-sidebar")
        // The boundary value: the window does not go off screen; if the screen allows, the 150th is visible without scrolling.
        let screen = NSScreen.main?.frame.height ?? 0
        XCTAssertLessThanOrEqual(picker.frame.maxY, screen, "вікно в межах екрана")
        let last = app.buttons["chapter-150"]
        if screen >= 900 { XCTAssertTrue(last.isHittable, "усі 150 розділів видно на екрані \(Int(screen)) pt") }
        last.scrollToVisible()
        shot("psalms-sidebar-scrolled")
        last.click()
        expectTitle("Psalms 150")
        // The chapter title in the toolbar is a dropdown with the open book's chapters.
        let title = app.descendants(matching: .any)["chapter-title"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.click()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(picker.frame.midY, title.frame.maxY, "вікно під назвою")
        XCTAssertEqual(app.buttons["chapter-150"].label, "Розділ 150, поточний")
        shot("psalms-title")
        let standard = app.buttons["chapter-23"].frame.width
        app.buttons["chapter-23"].click()
        expectTitle("Psalms 23")
        // The verse font (⌘+) also enlarges chapter numbers in the window.
        for _ in 0..<4 {
            app.menuBars.menuBarItems["View"].click()
            app.menuBars.menuItems["Збільшити шрифт"].click()
        }
        title.click()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(app.buttons["chapter-23"].frame.width, standard, "номери більші після ⌘+")
        shot("psalms-title-large-font")
    }
}

private extension XCUIElement {
    /// Scroll down until the button becomes visible in the chapter grid.
    func scrollToVisible() {
        var tries = 0
        while !isHittable, tries < 20 {
            XCUIApplication().descendants(matching: .any)["chapter-picker"].firstMatch.scroll(byDeltaX: 0, deltaY: -200)
            tries += 1
        }
    }
}
