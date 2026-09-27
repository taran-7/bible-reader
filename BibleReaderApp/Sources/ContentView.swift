import BibleCore
import SwiftUI

struct ContentView: View {
    @Bindable var model: ReaderViewModel
    let preferences: PreferencesStore

    private var scale: InterfaceScale { preferences.preferences.interfaceScale }

    var body: some View {
        if let error = model.loadError {
            DatabaseErrorView(message: error)
                .font(.system(size: scale.systemFontSize))
        } else {
            NavigationSplitView {
                BookList(model: model, fontSize: preferences.preferences.bookListFontSize)
                    .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            } detail: {
                Group {
                    if let error = model.searchError {
                        ContentUnavailableView(
                            "Пошук не вдався",
                            systemImage: "exclamationmark.triangle",
                            description: Text("Запит «\(model.submittedQuery)»: \(error)"))
                    } else if let results = model.results {
                        SearchResultsView(model: model, results: results)
                    } else {
                        ChapterView(model: model, fontSize: preferences.preferences.verseFontSize)
                    }
                }
                .font(.system(size: scale.systemFontSize))
                .toolbar { ReaderToolbar(model: model) }
                .controlSize(scale.controlSize)
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
        ContentUnavailableView {
            Label("Не вдалося відкрити базу", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
            Text("Перезберіть додаток після `make db`.")
        }
        .textSelection(.enabled)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("database-error")
    }
}
