import AppKit
import XCTest

/// FR-26, FR-27: a second translation alongside and switching translation while keeping the verse.
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

    /// The same items exist in the main menu and in the toolbar menu; click the one that is open.
    private func clickMenuItem(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let items = app.menuItems.matching(NSPredicate(format: "title == %@", title))
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if let item = items.allElementsBoundByIndex.first(where: \.isHittable) {
                item.click()
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("пункт меню «\(title)»", file: file, line: line)
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

        // The Synodal alongside: next to KJV Ps 22:1 stands Ps 21:1–2.
        // Via the main menu: the toolbar button hides in the overflow in the narrow CI window.
        app.menuBars.menuBarItems["Переклад"].click()
        app.menuBars.menuItems["Поруч"].hover()
        app.menuBars.menuItems["Синодальний"].click()
        // The Ps 22:1 row is read together with the parallel column: the superscription and Ps 21:2.
        let verse = app.descendants(matching: .any)["verse-1"].firstMatch
        XCTAssertTrue(verse.waitForExistence(timeout: 5))
        let found = XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "label CONTAINS 'Синодальний: 21:1 '"), evaluatedWith: verse)],
                                   timeout: 5)
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = "parallel-psalm-22"
        attachment.lifetime = .keepAlways
        add(attachment)
        let tree = XCTAttachment(string: app.windows.firstMatch.debugDescription)
        tree.name = "parallel-tree"
        tree.lifetime = .keepAlways
        add(tree)
        XCTAssertEqual(found, .completed, "мітка вірша 1: «\(verse.label)»")
        XCTAssertTrue(verse.label.contains("21:2 Боже мой! Боже мой!"), verse.label)

        // Switching to the Synodal: Ps 21 opens with verse 2 selected (the same content).
        app.menuBars.menuBarItems["Переклад"].click()
        app.menuBars.menuItems["Синодальний — русский"].click()
        expectTitle("Псалтирь 21")
        let row = app.outlineRows.containing(.any, identifier: "verse-2").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        wait(for: [expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: row)], timeout: 5)
    }
}
