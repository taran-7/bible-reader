import AppKit
import XCTest

/// FR-42: the visit history panel right of the text.
@MainActor
final class HistoryUITests: XCTestCase {
    private var app: XCUIApplication!
    private let profile = UUID().uuidString

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment = ["BIBLE_READER_PROFILE": profile]
    }

    override func tearDown() async throws {
        app.terminate()
    }

    private func launch() {
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-ResetReadingPreferences", "YES"]
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
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

    private func rows() -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "history-row")
    }

    // @trace FR-42
    func testJumpAddsARowThatSurvivesARestart() {
        launch()
        XCTAssertTrue(element("history-panel").waitForExistence(timeout: 5))
        XCTAssertTrue(element("history-empty").exists)
        search("John 3:16")
        let row = rows().firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(row.label, "John 3:16")

        app.terminate()
        app.launch()
        XCTAssertTrue(rows().firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(rows().firstMatch.label, "John 3:16")
    }

    // @trace FR-42
    func testClickingARowReturnsToThatVerse() {
        launch()
        search("John 3:16")
        search("Gen 1:1")
        XCTAssertTrue(rows().element(boundBy: 1).waitForExistence(timeout: 5))
        XCTAssertEqual(rows().element(boundBy: 0).label, "Genesis 1:1")
        rows().element(boundBy: 1).click()
        // John 3 is now open: the window title is the chapter.
        let window = app.windows.matching(NSPredicate(format: "title == %@", "John 3")).firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "вікно «John 3»")
    }

    // @trace FR-42
    func testClearEmptiesTheList() {
        launch()
        search("John 3:16")
        XCTAssertTrue(rows().firstMatch.waitForExistence(timeout: 5))
        element("history-clear").click()
        XCTAssertTrue(element("history-empty").waitForExistence(timeout: 5))
    }

    // @trace FR-42
    func testDraftsHideTheHistoryUntilTheToggleShowsIt() {
        launch()
        XCTAssertTrue(element("history-panel").waitForExistence(timeout: 5))
        element("drafts-toolbar").click()
        XCTAssertTrue(element("drafts-new").waitForExistence(timeout: 5))
        XCTAssertFalse(element("history-panel").exists)
        element("history-toolbar").click()
        XCTAssertTrue(element("history-panel").waitForExistence(timeout: 5))
    }

    // @trace FR-42
    func testSelectionButtonsStayLeftOfThePanel() {
        launch()
        // A jump selects the verse, so the selection buttons appear.
        search("John 3:16")
        guard let copy = app.visibleButton("copy-button") else { return XCTFail("кнопки копіювання не видно") }
        let panel = element("history-panel")
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(copy.frame.maxX, panel.frame.minX, "кнопки виділення не мають заходити під панель історії")
        // The history row at the same height stays clickable.
        XCTAssertTrue(rows().firstMatch.isHittable)
    }
}
