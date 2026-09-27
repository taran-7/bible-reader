import AppKit
import Carbon.HIToolbox
import XCTest

/// UI-докази для тем (FR-31): реальний Settings, реальний рендер, піксель фону під віршами.
@MainActor
final class ThemeUITests: XCTestCase {
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

    private func verseRow(_ verse: Int) -> XCUIElement {
        app.outlineRows.containing(.any, identifier: "verse-\(verse)").firstMatch
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

    private func choose(_ theme: String) {
        app.typeKey(physicalKey(kVK_ANSI_Comma, fallback: ","), modifierFlags: .command)
        let picker = app.popUpButtons["theme"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.click()
        picker.menuItems[theme].click()
        // Закриваємо саме вікно налаштувань: ⌘W міг би закрити головне вікно.
        let settings = app.windows["com_apple_SwiftUI_Settings_window"]
        settings.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertTrue(settings.waitForNonExistence(timeout: 5))
    }

    private func search(_ text: String) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        app.menuItems["selectAll:"].click()
        if text.isEmpty {
            field.typeKey(.delete, modifierFlags: [])
        } else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            app.menuItems["paste:"].click()
        }
        field.typeKey(.return, modifierFlags: [])
    }

    private func attach(_ label: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = label
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Колір пікселя в правому полі рядка вірша 1 (там немає тексту).
    private func backgroundPixel(saveAs label: String? = nil) -> (r: Int, g: Int, b: Int) {
        let window = app.windows.firstMatch
        let row = verseRow(1)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let shot = window.screenshot()
        let rep = NSBitmapImageRep(data: shot.image.tiffRepresentation!)!
        let scale = CGFloat(rep.pixelsWide) / window.frame.width
        let x = Int((row.frame.maxX - 12 - window.frame.minX) * scale)
        let y = Int((row.frame.midY - window.frame.minY) * scale)
        if let label {
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = label
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        let color = rep.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!
        return (Int(color.redComponent * 255), Int(color.greenComponent * 255), Int(color.blueComponent * 255))
    }

    private func expectBackground(_ hex: Int, tolerance: Int, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let expected = ((hex >> 16) & 0xFF, (hex >> 8) & 0xFF, hex & 0xFF)
        func close(_ p: (r: Int, g: Int, b: Int)) -> Bool {
            abs(p.r - expected.0) <= tolerance && abs(p.g - expected.1) <= tolerance && abs(p.b - expected.2) <= tolerance
        }
        let deadline = Date().addingTimeInterval(5)
        var pixel = backgroundPixel()
        while !close(pixel), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            pixel = backgroundPixel()
        }
        pixel = backgroundPixel(saveAs: label)
        XCTAssertTrue(close(pixel), "\(label): піксель \(pixel), очікувано #\(String(hex, radix: 16))", file: file, line: line)
    }

    // @trace FR-31
    func testThemeChangesBackgroundAndPersists() {
        launch(reset: true)
        choose("Темна")
        expectBackground(0x121214, tolerance: 6, "dark")
        choose("Пастельна")
        expectBackground(0xF7F3EE, tolerance: 6, "pastel")
        choose("Скло")
        expectBackground(0xF2F4F8, tolerance: 20, "glass")
        choose("Манускрипт")
        // Текстура ~7 % зсуває піксель від чистого пергаменту.
        expectBackground(0xEFE4CC, tolerance: 22, "manuscript")

        app.terminate()
        launch(reset: false)
        expectBackground(0xEFE4CC, tolerance: 22, "manuscript-relaunch")
        // Виділення, кнопка копіювання й підсвітка пошуку в темі — для огляду людиною.
        search("John 3:16")
        XCTAssertTrue(app.buttons.matching(identifier: "copy-button").firstMatch.waitForExistence(timeout: 5))
        attach("manuscript-selection")
        search("only begotten")
        XCTAssertTrue(app.buttons.matching(identifier: "search-result").firstMatch.waitForExistence(timeout: 5))
        attach("manuscript-search")
        search("")

        choose("Світла")
        expectBackground(0xFFFFFF, tolerance: 6, "light")

        // Із фіксованої темної назад до «Як у системі»: вікно має повернутися до схеми macOS.
        choose("Темна")
        expectBackground(0x121214, tolerance: 6, "dark-again")
        choose("Як у системі")
        let systemIsDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        expectBackground(systemIsDark ? 0x121214 : 0xFFFFFF, tolerance: 6, "system")
    }
}
