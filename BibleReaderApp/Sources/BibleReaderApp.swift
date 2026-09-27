import BibleCore
import SwiftUI

@main
struct BibleReaderApp: App {
    @State private var model = ReaderViewModel {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment // BIBLE_READER_DB для UI-тестів
        #else
        let environment: [String: String] = [:]
        #endif
        let url = try DatabaseLocation.url(
            environment: environment,
            bundled: Bundle.main.url(forResource: "bible", withExtension: "sqlite"))
        return try SQLiteBibleRepository(path: url)
    }
    @State private var preferences = BibleReaderApp.makePreferences()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model, preferences: preferences)
                .frame(minWidth: 800, minHeight: 500)
        }
        .commands { FontCommands(preferences: preferences) }

        Settings {
            SettingsView(preferences: preferences)
        }
    }

    private static func makePreferences() -> PreferencesStore {
        let store = PreferencesStore(storage: UserDefaults.standard)
        #if DEBUG
        // UI-тести стартують зі стандартних налаштувань.
        if UserDefaults.standard.bool(forKey: "ResetReadingPreferences") { store.reset() }
        #endif
        return store
    }
}

struct FontCommands: Commands {
    let preferences: PreferencesStore

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Divider()
            Button("Збільшити шрифт") { preferences.preferences.increaseVerseFont() }
                .keyboardShortcut("=", modifiers: .command)
                .disabled(!preferences.preferences.canIncreaseVerseFont)
            Button("Зменшити шрифт") { preferences.preferences.decreaseVerseFont() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(!preferences.preferences.canDecreaseVerseFont)
            Button("Стандартний розмір") { preferences.preferences.resetVerseFont() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(preferences.preferences.isVerseFontDefault)
        }
    }
}
