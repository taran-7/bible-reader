import AppKit
import XCTest

/// FR-26, FR-27: другий переклад поруч і перемикання перекладу зі збереженням вірша.
@MainActor
final class ParallelUITests: XCTestCase {
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

    private func expectTitle(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.matching(NSPredicate(format: "title == %@", title)).firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "вікно «\(title)»", file: file, line: line)
    }

    // @trace FR-26
    // @trace FR-27
    func testParallelPsalmAndSwitchKeepsVerse() {
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        search("Ps 22:1")
        expectTitle("Psalms 22")

        // Поруч — Синодальний: біля Пс 22:1 KJV стоїть Пс 21:1–2.
        let menu = app.descendants(matching: .any)["parallel"].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.click()
        app.menuItems["Синодальний — русский"].click()
        let column = app.descendants(matching: .any)["parallel-21-1"].firstMatch
        XCTAssertTrue(column.waitForExistence(timeout: 5))
        XCTAssertTrue(column.label.contains("Боже мой! Боже мой!"), column.label)
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = "parallel-psalm-22"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Перемикання на Синодальний: відкривається Пс 21, виділено вірш 2 (той самий зміст).
        app.menuBars.menuBarItems["Переклад"].click()
        app.menuBars.menuItems["Синодальний — русский"].click()
        expectTitle("Псалтирь 21")
        let row = app.outlineRows.containing(.any, identifier: "verse-2").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        wait(for: [expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: row)], timeout: 5)
    }
}
