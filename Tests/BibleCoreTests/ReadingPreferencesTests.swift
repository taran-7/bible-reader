import Foundation
import Testing
@testable import BibleCore

@Suite struct ReadingPreferencesTests {
    // @trace FR-15
    @Test func testDefaults() {
        let prefs = ReadingPreferences()
        #expect(prefs.verseFontSize == 15)
        #expect(prefs.bookListFontSize == 13)
        #expect(prefs.interfaceScale == .standard)
    }

    // @trace FR-15
    @Test func testIncreaseAndDecreaseStopAtBounds() {
        var prefs = ReadingPreferences()
        prefs.increaseFonts()
        #expect(prefs.verseFontSize == 16)
        for _ in 0..<100 { prefs.increaseFonts() }
        #expect(prefs.verseFontSize == ReadingPreferences.verseFontRange.upperBound)
        #expect(!prefs.canIncreaseFonts)
        for _ in 0..<100 { prefs.decreaseFonts() }
        #expect(prefs.verseFontSize == ReadingPreferences.verseFontRange.lowerBound)
        #expect(!prefs.canDecreaseFonts)
    }

    // @trace FR-15
    @Test func testShortcutsChangeBothSizes() {
        var prefs = ReadingPreferences()
        prefs.increaseFonts()
        #expect(prefs.verseFontSize == 16 && prefs.bookListFontSize == 14)
        prefs.decreaseFonts()
        prefs.decreaseFonts()
        #expect(prefs.verseFontSize == 14 && prefs.bookListFontSize == 12)
        prefs.verseFontSize = 20
        prefs.bookListFontSize = 18
        prefs.resetFonts()
        #expect(prefs.verseFontSize == 15 && prefs.bookListFontSize == 13)
        #expect(prefs.areFontsDefault)
        // Межі однакові: після багатьох ⌘+ обидва на 32.
        for _ in 0..<100 { prefs.increaseFonts() }
        #expect(prefs.verseFontSize == 32 && prefs.bookListFontSize == 32)
    }

    // @trace FR-15
    @Test func testSettersClamp() {
        var prefs = ReadingPreferences()
        prefs.verseFontSize = 100
        prefs.bookListFontSize = 1
        #expect(prefs.verseFontSize == 32)
        #expect(prefs.bookListFontSize == 11)
        prefs.bookListFontSize = 99
        #expect(prefs.bookListFontSize == 32)
        prefs.verseFontSize = 15.4
        #expect(prefs.verseFontSize == 15)
    }

    // @trace FR-16
    @Test func testInterfaceScaleMultipliesSystemBase() {
        #expect(InterfaceScale.allCases == [.small, .standard, .large, .extraLarge])
        #expect(InterfaceScale.standard.fontSize(base: 13) == 13)
        #expect(InterfaceScale.large.fontSize(base: 10) == 12)
        #expect(InterfaceScale.extraLarge.fontSize(base: 10) == 14)
        #expect(InterfaceScale.small.fontSize(base: 20) == 17)
        #expect(InterfaceScale.allCases.map(\.title) == ["Малий", "Стандарт", "Великий", "Дуже великий"])
    }
}

final class DictionaryStore: KeyValueStore, @unchecked Sendable {
    var values: [String: Data] = [:]
    func data(forKey key: String) -> Data? { values[key] }
    func set(_ data: Data, forKey key: String) { values[key] = data }
    func removeObject(forKey key: String) { values[key] = nil }
}

@MainActor @Suite struct PreferencesStoreTests {
    // @trace FR-15
    @Test func testChangesPersistAcrossStores() {
        let storage = DictionaryStore()
        let store = PreferencesStore(storage: storage)
        store.preferences.increaseFonts()
        store.preferences.bookListFontSize = 17
        store.preferences.interfaceScale = .large

        let reloaded = PreferencesStore(storage: storage)
        #expect(reloaded.preferences.verseFontSize == 16)
        #expect(reloaded.preferences.bookListFontSize == 17)
        #expect(reloaded.preferences.interfaceScale == .large)
    }

    // @trace FR-15
    @Test func testCorruptedDataFallsBackToDefaults() {
        let storage = DictionaryStore()
        storage.values[PreferencesStore.key] = Data("not json".utf8)
        #expect(PreferencesStore(storage: storage).preferences == ReadingPreferences())
    }

    // @trace FR-15
    @Test func testStoredOutOfRangeValuesAreClamped() {
        let storage = DictionaryStore()
        storage.values[PreferencesStore.key] = Data(#"{"verseFontSize":500,"bookListFontSize":13,"interfaceScale":"standard"}"#.utf8)
        #expect(PreferencesStore(storage: storage).preferences.verseFontSize == 32)
    }

    // @trace FR-15
    @Test func testPartialDataKeepsKnownValues() {
        let storage = DictionaryStore()
        storage.values[PreferencesStore.key] = Data(#"{"verseFontSize":20,"interfaceScale":"gigantic"}"#.utf8)
        let prefs = PreferencesStore(storage: storage).preferences
        #expect(prefs.verseFontSize == 20)
        #expect(prefs.bookListFontSize == 13)
        #expect(prefs.interfaceScale == .standard)

        storage.values[PreferencesStore.key] = Data(#"{"bookListFontSize":18}"#.utf8)
        #expect(PreferencesStore(storage: storage).preferences == ReadingPreferences(bookListFontSize: 18))
    }

    // @trace FR-15
    @Test func testReset() {
        let storage = DictionaryStore()
        let store = PreferencesStore(storage: storage)
        store.preferences.verseFontSize = 20
        store.reset()
        #expect(store.preferences == ReadingPreferences())
        #expect(PreferencesStore(storage: storage).preferences == ReadingPreferences())
    }
}

@MainActor @Suite struct UserDefaultsStoreTests {
    // @trace FR-15
    @Test func testUserDefaultsRoundTrip() throws {
        let name = "ReadingPreferencesTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }

        PreferencesStore(storage: defaults).preferences.verseFontSize = 21
        #expect(PreferencesStore(storage: defaults).preferences.verseFontSize == 21)
    }
}
