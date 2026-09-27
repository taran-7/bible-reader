import AppKit
import BibleCore
import SwiftUI
import UniformTypeIdentifiers

@main
struct BibleReaderApp: App {
    /// Закладки, підсвітки, нотатки й останнє місце — в окремій базі користувача.
    private static let userDatabase: Result<UserDatabase, any Error> = Result {
        #if DEBUG
        // UI-тести передають свій профіль, щоб стартувати з чистого стану.
        let profile = ProcessInfo.processInfo.environment["BIBLE_READER_PROFILE"]
        #else
        let profile: String? = nil
        #endif
        return try UserDatabase(path: UserDatabase.defaultURL(profile: profile))
    }
    @State private var userData = BibleReaderApp.makeUserData()
    @State private var model = ReaderViewModel(positionStore: try? BibleReaderApp.userDatabase.get()) {
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
                .environment(userData)
                .frame(minWidth: 800, minHeight: 500)
        }
        .commands {
            ExportCommands(userData: userData, model: model)
            BookmarkCommands(userData: userData, model: model)
            FindCommands()
            FontCommands(preferences: preferences)
            CommandGroup(after: .toolbar) { ThemePicker(preferences: preferences) }
            TranslationCommands(model: model)
        }

        WindowGroup("Порівняти", id: "compare", for: CompareRequest.self) { $request in
            if let request {
                CompareView(request: request, model: model, preferences: preferences)
                    .modifier(ThemedScene(preferences: preferences))
            }
        }

        Settings {
            SettingsView(preferences: preferences)
                .modifier(ThemedScene(preferences: preferences))
        }
    }

    init() {
        ThemeFonts.register()
    }

    private static func makeUserData() -> UserData {
        switch userDatabase {
        case .success(let database): UserData(database: database)
        case .failure(let error): UserData(unavailable: error)
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
            Button("Збільшити шрифт") { preferences.preferences.increaseFonts() }
                .keyboardShortcut("=", modifiers: .command)
                .disabled(!preferences.preferences.canIncreaseFonts)
            Button("Зменшити шрифт") { preferences.preferences.decreaseFonts() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(!preferences.preferences.canDecreaseFonts)
            Button("Стандартний розмір") { preferences.preferences.resetFonts() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(preferences.preferences.areFontsDefault)
            Divider()
        }
    }
}

/// Меню «Переклад» з ⌘⌥1…4.
struct TranslationCommands: Commands {
    let model: ReaderViewModel

    var body: some Commands {
        CommandMenu("Переклад") {
            ForEach(Array(Translation.allCases.enumerated()), id: \.element) { index, translation in
                Toggle(translation.menuTitle, isOn: Binding(
                    get: { model.translation == translation },
                    set: { if $0 { model.translation = translation } }))
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command, .option])
            }
        }
    }
}

/// Файл → експорт закладок, підсвіток і нотаток (FR-24).
struct ExportCommands: Commands {
    let userData: UserData
    let model: ReaderViewModel

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Button("Експортувати нотатки в JSON…") {
                save(name: "Bible Reader.json", type: .json) { try userData.exportJSON() }
            }
            Button("Експортувати нотатки в Markdown…") {
                save(name: "Bible Reader.md", type: UTType(filenameExtension: "md") ?? .plainText) {
                    Data(userData.exportMarkdown(in: model.translation).utf8)
                }
            }
        }
    }

    private func save(name: String, type: UTType, contents: () throws -> Data) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [type]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try contents().write(to: url, options: .atomic)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

/// ⌘D у меню, а не на кнопці тулбара: працює й тоді, коли тулбар сховано.
struct BookmarkCommands: Commands {
    let userData: UserData
    let model: ReaderViewModel

    var body: some Commands {
        CommandMenu("Закладки") {
            let chapter = Bookmark.Target(book: model.location.book, chapter: model.location.chapter, verse: nil)
            Button(userData.isBookmarked(chapter) ? "Прибрати закладку розділу" : "Закладка на розділ") {
                userData.toggleBookmark(chapter)
            }
            .keyboardShortcut("d", modifiers: .command)
        }
    }
}

/// ⌘F переводить фокус у поле пошуку (NFR-4: робота з клавіатури).
struct FindCommands: Commands {
    var body: some Commands {
        // Замість системного «Знайти…» (панель пошуку в тексті), щоб не було двох ⌘F.
        CommandGroup(replacing: .textEditing) {
            Button("Знайти") {
                let item = NSApp.keyWindow?.toolbar?.items.lazy.compactMap { $0 as? NSSearchToolbarItem }.first
                item?.beginSearchInteraction()
            }
            .keyboardShortcut("f", modifiers: .command)
        }
    }
}
