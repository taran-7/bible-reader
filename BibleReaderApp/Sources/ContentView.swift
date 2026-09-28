import BibleCore
import SwiftUI

struct ContentView: View {
    @Bindable var model: ReaderViewModel
    let preferences: PreferencesStore
    @Environment(UserData.self) private var userData

    private var scale: InterfaceScale { preferences.preferences.interfaceScale }

    var body: some View {
        content.modifier(ThemedScene(preferences: preferences))
        #if DEBUG
            .overlay(alignment: .bottomLeading) {
                // Лише Debug; VoiceOver у Debug прочитає це число — свідомо, Release його не має.
                if let launchMilliseconds = model.launchMilliseconds {
                    Text(verbatim: String(launchMilliseconds))
                        .font(.system(size: 1))
                        .opacity(0.01)
                        .accessibilityIdentifier("launch-time")
                }
            }
        #endif
    }

    @ViewBuilder private var content: some View {
        if let error = model.loadError {
            DatabaseErrorView(message: error)
                .background(ThemeBackground())
        } else {
            NavigationSplitView {
                BookList(model: model, fontSize: preferences.preferences.bookListFontSize,
                         verseFontSize: preferences.preferences.verseFontSize)
                    .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            } detail: {
                Group {
                    if model.searchError != nil || model.results != nil {
                        SearchResultsView(model: model)
                    } else {
                        ChapterView(model: model, fontSize: preferences.preferences.verseFontSize)
                    }
                }
                .font(.system(size: scale.systemFontSize))
                .toolbar { ReaderToolbar(model: model, userData: userData, preferences: preferences, scale: scale) }
                .modifier(ToolbarTheme())
                .modifier(HiddenToolbarTitle())
            }
            .safeAreaInset(edge: .top) { UserDataWarning() }
            // Паралельний переклад з налаштувань; той самий, що основний, — вимкнено.
            .onChange(of: [preferences.preferences.parallelTranslation, model.translation], initial: true) {
                let other = preferences.preferences.parallelTranslation
                model.parallelTranslation = other == model.translation ? nil : other
            }
            .modifier(SearchField(query: $model.query))
            .onSubmit(of: .search) { model.submitSearch() }
            .onChange(of: model.query) { _, query in
                if query.isEmpty { model.submitSearch() }
            }
        }
    }
}

struct DatabaseErrorView: View {
    let message: String

    var body: some View {
        MessageView(
            title: "Не вдалося відкрити базу",
            systemImage: "exclamationmark.triangle",
            lines: [message, "Перезберіть додаток після «make db»."])
        .textSelection(.enabled)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("database-error")
    }
}

/// Помилка бази користувача: без неї нотатки тихо губилися б після перезапуску.
struct UserDataWarning: View {
    @Environment(UserData.self) private var userData

    var body: some View {
        if let error = userData.lastError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(userData.isInMemoryOnly
                     ? "Закладки й нотатки не зберігаються: базу користувача не відкрито (\(error))."
                     : "Не вдалося зберегти зміну: \(error)")
                    .textSelection(.enabled)
                Spacer()
                if !userData.isInMemoryOnly {
                    Button("Закрити") { userData.dismissError() }
                }
            }
            .padding(8)
            .background(.bar)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("userdata-error")
        }
    }
}

/// Назву розділу в тулбарі показує кнопка вибору розділу; системний заголовок у тулбарі ховаємо,
/// а заголовок вікна лишається (меню «Window», VoiceOver). На macOS 14 без API — обидва видно.
struct HiddenToolbarTitle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.toolbar(removing: .title)
        } else {
            content
        }
    }
}

/// Поле пошуку по центру тулбара, а не праворуч (запит власника 2026-09-28).
/// `.toolbarPrincipal` є лише в SDK нових Xcode (Swift 6.2+); зі старішим (CI на macos-15) поле праворуч.
struct SearchField: ViewModifier {
    @Binding var query: String

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        content.searchable(text: $query, placement: .toolbarPrincipal, prompt: "Слово або посилання (Ин 3:16)")
        #else
        content.searchable(text: $query, prompt: "Слово або посилання (Ин 3:16)")
        #endif
    }
}
