import AppKit
import XCTest

/// FR-36: «Порівняти» — режим у головному вікні; вибір перекладів переживає перезапуск.
@MainActor
final class CompareUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment = ["BIBLE_READER_PROFILE": UUID().uuidString]
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

    /// «Порівняти» на виділеному вірші → вибір перекладів → режим у головному вікні.
    private func openCompare(_ reference: String) -> XCUIElement {
        search(reference)
        guard let button = app.visibleButton("compare-button") else {
            XCTFail("кнопки «Порівняти» не видно")
            return app.windows.firstMatch
        }
        button.click()
        let start = app.buttons["compare-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        return app.windows.firstMatch
    }

    // @trace FR-36
    func testCompareModeInMainWindowRemembersTranslations() {
        launch(reset: true)
        let window = openCompare("John 3:16")
        // Переклад на екрані не пропонується: він завжди перша колонка.
        XCTAssertFalse(app.checkBoxes["compare-choice-kjv"].exists)
        app.checkBoxes["compare-choice-bkr"].click()
        app.buttons["compare-start"].click()
        let mode = window.descendants(matching: .any)["compare-mode"].firstMatch
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        XCTAssertEqual(app.windows.count, 1, "порівняння — у тому самому вікні")
        for code in ["kjv", "ohienko", "synodal"] {
            XCTAssertTrue(mode.descendants(matching: .any)["compare-column-\(code)"].exists, code)
        }
        XCTAssertFalse(mode.descendants(matching: .any)["compare-column-bkr"].exists)
        // Увесь розділ: є і сусідні вірші, а виділений підсвічено.
        XCTAssertTrue(mode.descendants(matching: .any)["compare-row-15"].exists)
        XCTAssertTrue(mode.descendants(matching: .any)["compare-row-16-selected"].exists)
        XCTAssertFalse(mode.descendants(matching: .any)["compare-row-15-selected"].exists)
        let attachment = XCTAttachment(screenshot: window.screenshot())
        attachment.name = "compare"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Esc — назад до читання.
        window.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(mode.waitForNonExistence(timeout: 5))

        // Вибір запам'ятовується.
        app.terminate()
        launch(reset: false)
        _ = openCompare("Ps 23:1")
        XCTAssertEqual(app.checkBoxes["compare-choice-bkr"].value as? Int, 0)
        XCTAssertEqual(app.checkBoxes["compare-choice-synodal"].value as? Int, 1)
    }
}
