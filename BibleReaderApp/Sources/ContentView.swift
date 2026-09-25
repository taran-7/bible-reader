import BibleCore
import SwiftUI

struct ContentView: View {
    @Bindable var model: ReaderViewModel

    var body: some View {
        if let error = model.loadError {
            DatabaseErrorView(message: error)
        } else {
            NavigationSplitView {
                BookList(model: model)
                    .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            } detail: {
                Group {
                    if let results = model.results {
                        SearchResultsView(model: model, results: results)
                    } else {
                        ChapterView(model: model)
                    }
                }
                .toolbar { ReaderToolbar(model: model) }
            }
            .searchable(text: $model.query, prompt: "Слово або посилання (Ин 3:16)")
            .onSubmit(of: .search) { model.submitSearch() }
            .onChange(of: model.query) { _, query in
                if query.isEmpty { model.submitSearch() }
            }
            .onChange(of: model.translation) { _, _ in
                if model.results != nil { model.submitSearch() }
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
    }
}
