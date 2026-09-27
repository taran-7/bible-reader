import BibleCore
import SwiftUI

struct ContentView: View {
    @Bindable var model: ReaderViewModel
    let preferences: PreferencesStore

    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var scale: InterfaceScale { preferences.preferences.interfaceScale }
    private var choice: ThemeChoice { preferences.preferences.theme }
    private var theme: ThemeTokens {
        Theme.tokens(
            for: choice.resolve(systemIsDark: systemScheme == .dark),
            reduceTransparency: reduceTransparency,
            increaseContrast: contrast == .increased)
    }

    var body: some View {
        themed(content)
    }

    /// Для «Як у системі» схему не нав'язуємо, інакше `systemScheme` перестане відбивати macOS.
    private func themed(_ view: some View) -> some View {
        view
            .environment(\.theme, theme)
            .environment(\.interfaceScale, scale)
            .foregroundStyle(Color(theme.text))
            .tint(Color(theme.accent))
            .preferredColorScheme(choice == .system ? nil : theme.preferredColorScheme)
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
                    if let error = model.searchError {
                        MessageView(
                            title: "Пошук не вдався",
                            systemImage: "exclamationmark.triangle",
                            lines: ["Запит «\(model.submittedQuery)»: \(error)"])
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(ThemeBackground())
                    } else if let results = model.results {
                        SearchResultsView(model: model, results: results)
                    } else {
                        ChapterView(model: model, fontSize: preferences.preferences.verseFontSize)
                    }
                }
                .font(.system(size: scale.systemFontSize))
                .toolbar { ReaderToolbar(model: model, scale: scale) }
                .modifier(ToolbarTheme())
            }
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
