import BibleCore
import SwiftUI

struct ContentView: View {
    @Bindable var model: ReaderViewModel
    let preferences: PreferencesStore
    @Environment(UserData.self) private var userData

    private var scale: InterfaceScale { preferences.preferences.interfaceScale }

    var body: some View {
        content.modifier(ThemedScene(preferences: preferences))
    }

    @ViewBuilder private var content: some View {
        if let error = model.loadError {
            DatabaseErrorView(message: error)
                .background(ThemeBackground())
        } else {
            NavigationSplitView {
                BookList(model: model, fontSize: preferences.preferences.bookListFontSize)
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
                .toolbar { ReaderToolbar(model: model, userData: userData, scale: scale) }
                .modifier(ToolbarTheme())
            }
            .safeAreaInset(edge: .top) { UserDataWarning() }
            .searchable(text: $model.query, prompt: "Слово або посилання (Ин 3:16)")
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
