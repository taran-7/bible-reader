import AppKit
import XCTest

/// FR-38…FR-40: a draft with a verse survives a restart; "Sermon" mode closes with Esc.
@MainActor
final class DraftsUITests: XCTestCase {
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

    // @trace FR-38
    // @trace FR-39
    // @trace FR-40
    func testDraftWithVerseSurvivesRestartAndSermonMode() {
        launch()
        element("drafts-toolbar").click()
        XCTAssertTrue(element("drafts-new-sermon").waitForExistence(timeout: 5))
        element("drafts-new-sermon").click()
        let title = element("draft-title")
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.click()
        title.typeText("Про любов")

        // The verse on the selection goes to the end of the draft.
        search("John 3:16")
        guard let button = app.visibleButton("draft-button") else { return XCTFail("кнопки «В чорнетку» не видно") }
        button.click()
        let text = app.textViews["draft-text"].firstMatch
        let predicate = NSPredicate(format: "value CONTAINS %@", "(John 3:16)")
        wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: text)], timeout: 5)
        XCTAssertTrue(element("draft-references").exists, "живе посилання під текстом")
        // A verse row is one accessibility element (children: .ignore): the marker is visible in its label.
        let marked = NSPredicate(format: "label CONTAINS %@", "є в чорнетках")
        wait(for: [XCTNSPredicateExpectation(predicate: marked, object: element("verse-16"))], timeout: 5)

        // "Sermon" mode and Esc.
        element("draft-present").click()
        XCTAssertTrue(element("sermon-mode").waitForExistence(timeout: 5))
        app.windows.firstMatch.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element("sermon-mode").waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.textViews["draft-text"].exists, "після Esc — знову панель із чорнеткою")

        app.terminate()
        launch()
        element("drafts-toolbar").click()
        let row = element("draft-row")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        // The row is a button: the title is in its label (on CI there is no separate staticText inside).
        XCTAssertTrue(app.buttons.matching(identifier: "draft-row").matching(NSPredicate(format: "label CONTAINS %@", "Про любов")).count
                      + app.staticTexts.matching(NSPredicate(format: "label == %@", "Про любов")).count > 0, "чорнетка «Про любов» після перезапуску")
    }
}
