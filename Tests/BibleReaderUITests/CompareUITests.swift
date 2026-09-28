import AppKit
import XCTest

/// FR-36: вікно «Порівняти» з панелями перекладів; закриття й перестановка переживають перезапуск.
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

    private func openCompare(_ reference: String) -> XCUIElement {
        search(reference)
        let button = app.buttons.matching(identifier: "compare-button").firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.click()
        let window = app.windows.matching(NSPredicate(format: "title BEGINSWITH 'Порівняти'")).firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        return window
    }

    private func panelOrder(in window: XCUIElement) -> [String] {
        let codes = ["kjv", "bkr", "ohienko", "synodal"]
        return codes
            .compactMap { code -> (String, CGFloat)? in
                let panel = window.descendants(matching: .any)["compare-panel-\(code)"].firstMatch
                return panel.exists ? (code, panel.frame.minX) : nil
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    // @trace FR-36
    func testComparePanelsCloseMoveAndPersist() {
        launch(reset: true)
        var window = openCompare("John 3:16")
        XCTAssertEqual(panelOrder(in: window), ["kjv", "bkr", "ohienko", "synodal"])
        XCTAssertTrue(window.staticTexts["J 3:16"].exists)
        XCTAssertTrue(window.staticTexts["Нумерація може відрізнятися"].exists)
        let attachment = XCTAttachment(screenshot: window.screenshot())
        attachment.name = "compare"
        attachment.lifetime = .keepAlways
        add(attachment)

        window.buttons["compare-close-bkr"].click()
        window.buttons["compare-left-synodal"].click()
        XCTAssertEqual(panelOrder(in: window), ["kjv", "synodal", "ohienko"])

        app.terminate()
        launch(reset: false)
        window = openCompare("Ps 23:1")
        XCTAssertEqual(panelOrder(in: window), ["kjv", "synodal", "ohienko"])

        // «+ Переклад» повертає закриту панель праворуч.
        window.descendants(matching: .any)["compare-add"].firstMatch.click()
        // Такий самий пункт є в головному меню «Переклад» — беремо той, що відкритий.
        let items = app.menuItems.matching(NSPredicate(format: "title == %@", "Kralická — čeština"))
        let deadline = Date().addingTimeInterval(5)
        var clicked = false
        while !clicked, Date() < deadline {
            if let item = items.allElementsBoundByIndex.first(where: \.isHittable) {
                item.click()
                clicked = true
            } else {
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            }
        }
        XCTAssertTrue(clicked, "пункт «Kralická — čeština»")
        XCTAssertEqual(panelOrder(in: window), ["kjv", "synodal", "ohienko", "bkr"])
    }
}
