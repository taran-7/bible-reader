import Foundation
import Testing
@testable import BibleCore

@Suite struct ContrastTests {
    // @trace FR-32
    @Test func testKnownContrastRatios() {
        let black = ThemeColor(hex: 0x000000), white = ThemeColor(hex: 0xFFFFFF)
        #expect(abs(black.contrast(with: white) - 21) < 0.01)
        #expect(abs(white.contrast(with: black) - 21) < 0.01)
        #expect(abs(white.contrast(with: white) - 1) < 0.001)
        // Сірий #767676 на білому — класична межа AA (4,54:1).
        #expect(abs(ThemeColor(hex: 0x767676).contrast(with: white) - 4.54) < 0.01)
    }

    // @trace FR-32
    @Test func testCompositing() {
        let white = ThemeColor(hex: 0xFFFFFF), black = ThemeColor(hex: 0x000000)
        #expect(white.composited(over: black, opacity: 1) == white)
        #expect(white.composited(over: black, opacity: 0) == black)
        let half = white.composited(over: black, opacity: 0.5)
        #expect(abs(half.red - 0.5) < 0.001)
    }

    // @trace FR-32
    @Test func testHexRoundTrip() {
        #expect(ThemeColor(hex: 0xEFE4CC).hex == 0xEFE4CC)
    }
}

@Suite struct ThemeTests {
    static let flags: [(reduceTransparency: Bool, increaseContrast: Bool)] =
        [(false, false), (true, false), (false, true), (true, true)]

    // @trace FR-31
    @Test func testPaletteMatchesPRD() {
        let light = Theme.tokens(for: .light)
        #expect(light.background.hex == 0xFFFFFF && light.text.hex == 0x1C1C1E)
        #expect(light.secondaryText.hex == 0x6E6E73 && light.accent.hex == 0x0A66C2)
        let dark = Theme.tokens(for: .dark)
        #expect(dark.background.hex == 0x121214 && dark.text.hex == 0xE8E6E3 && dark.colorScheme == .dark)
        let glass = Theme.tokens(for: .glass)
        #expect(glass.background.hex == 0xF2F4F8 && glass.plateOpacity == 0.92 && glass.usesGlass)
        #expect(glass.font == .sfPro)
        let pastel = Theme.tokens(for: .pastel)
        #expect(pastel.background.hex == 0xF7F3EE && pastel.text.hex == 0x2E3440 && pastel.sidebar.hex == 0xE3EDF7)
        let manuscript = Theme.tokens(for: .manuscript)
        #expect(manuscript.background.hex == 0xEFE4CC && manuscript.text.hex == 0x3B2A1A)
        #expect(manuscript.verseNumber.hex == 0x8B2E1F && manuscript.font == .ebGaramond)
        #expect(manuscript.textureOpacity > 0.04 && manuscript.textureOpacity < 0.11)
        #expect(light.textureOpacity == 0 && light.font == .newYork)
        for id in ThemeID.allCases { #expect(Theme.tokens(for: id).lineSpacing == 0.5) }
    }

    // @trace FR-32
    @Test(arguments: ThemeID.allCases)
    func testEveryPairPassesContrast(_ id: ThemeID) {
        for flag in Self.flags {
            let t = Theme.tokens(for: id, reduceTransparency: flag.reduceTransparency, increaseContrast: flag.increaseContrast)
            let context = "\(id) \(flag)"
            // Підкладка під віршами: гірший випадок з чорним і білим тлом під нею.
            for plate in t.effectiveBackgrounds {
                #expect(t.text.contrast(with: plate) >= 7, "\(context): текст/фон")
                #expect(t.secondaryText.contrast(with: plate) >= 4.5, "\(context): другорядний/фон")
                #expect(t.accent.contrast(with: plate) >= 4.5, "\(context): акцент/фон")
                #expect(t.verseNumber.contrast(with: plate) >= 4.5, "\(context): номер вірша/фон")
                #expect(t.text.contrast(with: t.selection) >= 7, "\(context): текст/виділення")
                // Кнопка копіювання в спокої: підкладка 0,6 на фоні, іконка непрозора.
                let button = t.copyButton.composited(over: plate, opacity: 0.6)
                #expect(t.accent.contrast(with: button) >= 4.5, "\(context): кнопка копіювання")
            }
            #expect(t.text.contrast(with: t.sidebar) >= 7, "\(context): текст/бічна панель")
            #expect(t.secondaryText.contrast(with: t.sidebar) >= 4.5, "\(context): другорядний/бічна панель")
            #expect(t.text.contrast(with: t.results) >= 7, "\(context): текст/результати")
            #expect(t.text.contrast(with: t.searchHighlight) >= 4.5, "\(context): текст/підсвітка")
            // Підсвітка помітна на фоні результатів.
            #expect(t.searchHighlight != t.results, "\(context): підсвітка видима")
        }
    }

    // @trace FR-31
    @Test func testSystemChoiceFollowsMacOS() {
        #expect(ThemeChoice.system.resolve(systemIsDark: false) == .light)
        #expect(ThemeChoice.system.resolve(systemIsDark: true) == .dark)
        #expect(ThemeChoice.theme(.manuscript).resolve(systemIsDark: true) == .manuscript)
        #expect(ThemeChoice.allCases.first == .system)
        #expect(ThemeChoice.allCases.count == 6)
        #expect(ThemeChoice.allCases.map(\.title) == ["Як у системі", "Світла", "Темна", "Скло", "Пастельна", "Манускрипт"])
    }

    // @trace FR-31
    @Test func testReduceTransparencyMakesGlassOpaque() {
        let t = Theme.tokens(for: .glass, reduceTransparency: true, increaseContrast: false)
        #expect(t.plateOpacity == 1 && !t.usesGlass)
        #expect(Theme.tokens(for: .manuscript, reduceTransparency: true, increaseContrast: false).textureOpacity == 0)
    }

    // @trace FR-31
    @Test func testIncreaseContrastStrengthensColors() {
        let normal = Theme.tokens(for: .pastel)
        let strong = Theme.tokens(for: .pastel, reduceTransparency: false, increaseContrast: true)
        #expect(strong.text.contrast(with: strong.background) > normal.text.contrast(with: normal.background))
        #expect(strong.accent.contrast(with: strong.background) >= 7)
        #expect(Theme.tokens(for: .dark, reduceTransparency: false, increaseContrast: true).text.hex == 0xFFFFFF)
    }

    // @trace FR-31
    @Test func testThemePersistsInPreferences() throws {
        var prefs = ReadingPreferences()
        #expect(prefs.theme == .system)
        prefs.theme = .theme(.pastel)
        let data = try JSONEncoder().encode(prefs)
        #expect(try JSONDecoder().decode(ReadingPreferences.self, from: data).theme == .theme(.pastel))
        let old = Data(#"{"verseFontSize":20,"bookListFontSize":13,"interfaceScale":"standard"}"#.utf8)
        #expect(try JSONDecoder().decode(ReadingPreferences.self, from: old).theme == .system)
    }
}
