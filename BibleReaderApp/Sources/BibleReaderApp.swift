import AppKit
import BibleCore
import SwiftUI
import UniformTypeIdentifiers

@main
struct BibleReaderApp: App {
    /// Bookmarks, highlights, notes and the last position live in a separate user database.
    private static let userDatabase: Result<UserDatabase, any Error> = Result {
        #if DEBUG
        // UI tests pass their own profile to start from a clean state.
        let profile = ProcessInfo.processInfo.environment["BIBLE_READER_PROFILE"]
        #else
        let profile: String? = nil
        #endif
        return try UserDatabase(path: UserDatabase.defaultURL(profile: profile))
    }
    @State private var userData = BibleReaderApp.makeUserData()
    /// Sermon drafts in the same user database (FR-38).
    @State private var drafts = DraftStore(database: try? BibleReaderApp.userDatabase.get())
    @State private var model = ReaderViewModel(positionStore: try? BibleReaderApp.userDatabase.get()) {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment // BIBLE_READER_DB for UI tests
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
                .environment(drafts)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear { TranslationKeyMonitor.install(model: model) }
        }
        .commands {
            ExportCommands(userData: userData, model: model)
            BookmarkCommands(userData: userData, model: model)
            CommandGroup(after: .sidebar) {
                Button(drafts.isOpen ? "Сховати чорнетки" : "Чорнетки") { drafts.isOpen.toggle() }
                    .keyboardShortcut("d", modifiers: [.command, .option])
            }
            CommandGroup(after: .pasteboard) {
                Button("Зняти виділення") { model.clearSelection() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .disabled(!model.canClearSelection || drafts.isOpen || drafts.isPresenting)
            }
            FindCommands()
            FontCommands(preferences: preferences, drafts: drafts)
            CommandGroup(after: .toolbar) { ThemePicker(preferences: preferences) }
            TranslationCommands(model: model, preferences: preferences)
        }


        Settings {
            SettingsView(preferences: preferences)
                .modifier(ThemedScene(preferences: preferences))
        }
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
        // UI tests start from default settings.
        if UserDefaults.standard.bool(forKey: "ResetReadingPreferences") { store.reset() }
        #endif
        return store
    }
}

struct FontCommands: Commands {
    let preferences: PreferencesStore
    /// In "Sermon" mode ⌘+ / ⌘− change its font, not the reading font (FR-40).
    let drafts: DraftStore

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Divider()
            if drafts.isPresenting {
                Button("Збільшити шрифт проповіді") { drafts.changeSermonFont(by: 2) }
                    .keyboardShortcut("=", modifiers: .command)
                Button("Зменшити шрифт проповіді") { drafts.changeSermonFont(by: -2) }
                    .keyboardShortcut("-", modifiers: .command)
            } else {
                Button("Збільшити шрифт") { preferences.preferences.increaseFonts() }
                    .keyboardShortcut("=", modifiers: .command)
                    .disabled(!preferences.preferences.canIncreaseFonts)
                Button("Зменшити шрифт") { preferences.preferences.decreaseFonts() }
                    .keyboardShortcut("-", modifiers: .command)
                    .disabled(!preferences.preferences.canDecreaseFonts)
            }
            Button("Стандартний розмір") { preferences.preferences.resetFonts() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(preferences.preferences.areFontsDefault)
            Divider()
        }
    }
}

/// ⌘⌥1…9 by the physical digit-row key: the menu's `keyboardShortcut` compares the character,
/// and on the Czech layout the digit row without Shift gives `+ ě š č` (tech debt #23).
/// A local monitor sees the event before the menu, so the translation does not switch twice.
@MainActor enum TranslationKeyMonitor {
    private static var token: Any?

    static func install(model: ReaderViewModel) {
        guard token == nil else { return }
        token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.intersection([.command, .option, .control, .shift]) == [.command, .option],
                  let index = TranslationShortcut.index(forKeyCode: event.keyCode),
                  index < Translation.allCases.count
            else { return event }
            model.translation = Translation.allCases[index]
            return nil
        }
    }
}

/// The Translation menu: the first nine translations from the manifest get ⌘⌥1…9, the rest no shortcut.
struct TranslationCommands: Commands {
    let model: ReaderViewModel
    let preferences: PreferencesStore

    var body: some Commands {
        CommandMenu("Переклад") {
            ForEach(Array(Translation.allCases.enumerated()), id: \.element) { index, translation in
                let toggle = Toggle(translation.menuTitle, isOn: Binding(
                    get: { model.translation == translation },
                    set: { if $0 { model.translation = translation } }))
                if let key = TranslationShortcut.digit(forIndex: index) {
                    toggle.keyboardShortcut(KeyEquivalent(key), modifiers: [.command, .option])
                } else {
                    toggle
                }
            }
            Divider()
            // The second translation alongside (FR-26): here too, because the toolbar button hides in a narrow window.
            Menu("Поруч") {
                Toggle("Вимкнено", isOn: Binding(
                    get: { model.parallelTranslation == nil },
                    set: { if $0 { preferences.preferences.parallelTranslation = nil } }))
                ForEach(Translation.allCases.filter { $0 != model.translation }, id: \.self) { translation in
                    Toggle(translation.title, isOn: Binding(
                        get: { model.parallelTranslation == translation },
                        set: { if $0 { preferences.preferences.parallelTranslation = translation } }))
                }
            }
        }
    }
}

/// File → export of bookmarks, highlights and notes (FR-24).
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
        FileExport.save(name: name, type: type, contents: contents)
    }
}

/// ⌘D in the menu, not on the toolbar button: works even when the toolbar is hidden.
struct BookmarkCommands: Commands {
    let userData: UserData
    let model: ReaderViewModel

    var body: some Commands {
        CommandMenu("Закладки") {
            let chapter = model.canonicalChapter
            Button(userData.isBookmarked(chapter) ? "Прибрати закладку розділу" : "Закладка на розділ") {
                userData.toggleBookmark(chapter)
            }
            .keyboardShortcut("d", modifiers: .command)
        }
    }
}

/// ⌘F moves focus to the search field (NFR-4: keyboard operation).
struct FindCommands: Commands {
    var body: some Commands {
        // Replaces the system "Find…" (the in-text find bar), so there are not two ⌘F.
        CommandGroup(replacing: .textEditing) {
            Button("Знайти") {
                guard let window = NSApp.keyWindow, let items = window.toolbar?.items else { return }
                if let item = items.lazy.compactMap({ $0 as? NSSearchToolbarItem }).first {
                    item.beginSearchInteraction()
                } else if let field = items.lazy.compactMap({ $0.view.flatMap(Self.searchField(in:)) }).first {
                    // The field in the toolbar center (.toolbarPrincipal) is a plain NSSearchField inside an item.
                    window.makeFirstResponder(field)
                }
            }
            .keyboardShortcut("f", modifiers: .command)
        }
    }

    private static func searchField(in view: NSView) -> NSSearchField? {
        if let field = view as? NSSearchField { return field }
        return view.subviews.lazy.compactMap(searchField(in:)).first
    }
}
