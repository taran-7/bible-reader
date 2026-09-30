import BibleCore
import SwiftUI

struct SearchResultsView: View {
    @Bindable var model: ReaderViewModel
    @Environment(UserData.self) private var userData
    @Environment(\.interfaceScale) private var scale
    @Environment(\.theme) private var theme

    var body: some View {
        // Notes with the query text (FR-24) above the verses; computed once.
        let notes = userData.searchNotes(model.submittedQuery)
        // The scope bar is visible on the error screen too: otherwise the scope search failed with could not be changed.
        VStack(spacing: 0) {
            header
            if let error = model.searchError {
                MessageView(
                    title: "Пошук не вдався",
                    systemImage: "exclamationmark.triangle",
                    lines: ["Запит «\(model.submittedQuery)»: \(error)"])
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !(model.results ?? []).isEmpty || !notes.isEmpty {
                list(model.results ?? [], notes: notes)
            } else {
                MessageView(
                    title: "Нічого не знайдено",
                    systemImage: "magnifyingglass",
                    lines: ["За запитом «\(model.submittedQuery)» в перекладі \(model.translation.title) (\(scopeTitle(model.searchScope))) немає віршів."])
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(theme.results))
        .navigationTitle("Пошук: «\(model.submittedQuery)»")
    }

    private func scopeTitle(_ scope: SearchScope) -> String {
        switch scope {
        case .bible: "уся Біблія"
        case .oldTestament: "Старий Завіт"
        case .newTestament: "Новий Завіт"
        case .book: bookTitle
        }
    }

    /// Search scope (FR-19) and counter (FR-20).
    private var header: some View {
        HStack(spacing: 12) {
            Picker("Де шукати", selection: $model.searchScope) {
                ForEach([SearchScope.bible, .oldTestament, .newTestament], id: \.self) { Text(scopeTitle($0).capitalizedFirst).tag($0) }
                Text(bookTitle).tag(model.currentBookScope)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .accessibilityIdentifier("search-scope")
            Spacer(minLength: 0)
            Text("Знайдено: \(model.resultTotal)")
                .foregroundStyle(Color(theme.secondaryText))
                .accessibilityIdentifier("search-count")
        }
        .controlSize(scale.controlSize)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var bookTitle: String {
        guard case .book(let number) = model.currentBookScope, let book = Book(number: number) else { return "Книга" }
        return book.name(in: model.translation)
    }

    private func list(_ results: [SearchResult], notes: [Note]) -> some View {
        List {
            if !notes.isEmpty {
                Section("Нотатки") {
                    ForEach(notes) { note in
                        Button {
                            model.openNote(note.key)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(model.localReference(book: note.key.book, chapter: note.key.chapter, verse: note.key.verse)
                                          .format(in: model.translation), systemImage: "note.text")
                                    .font(.system(size: scale.systemFontSize * 1.1, weight: .semibold))
                                    .foregroundStyle(Color(theme.accent))
                                Text(note.text).lineLimit(3).foregroundStyle(Color(theme.text))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("note-result")
                        .listRowBackground(Color(theme.results))
                        .listRowSeparator(.hidden)
                    }
                }
            }
            if !results.isEmpty, !notes.isEmpty {
                Section("Вірші") {}
            }
            ForEach(results) { result in
                Button { model.open(result) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Reference(book: result.verse.book, chapter: result.verse.chapter, verseStart: result.verse.verse)
                            .format(in: result.verse.translation))
                            .font(.system(size: scale.systemFontSize * 1.1, weight: .semibold))
                            .foregroundStyle(Color(theme.accent))
                        Text(highlighted(result.segments)).foregroundStyle(Color(theme.text))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("search-result")
                .listRowBackground(Color(theme.results))
                .listRowSeparator(.hidden)
            }
            if let error = model.pageError {
                HStack {
                    Text("Не вдалося довантажити: \(error)").foregroundStyle(Color(theme.secondaryText))
                    Button("Повторити") { model.loadMore() }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color(theme.results))
                .listRowSeparator(.hidden)
            } else if model.canLoadMore {
                // Load more when scrolled to the end (FR-20).
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .onAppear { model.loadMore() }
                    .accessibilityIdentifier("search-load-more")
                    .listRowBackground(Color(theme.results))
                    .listRowSeparator(.hidden)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func highlighted(_ segments: [SearchResult.Segment]) -> AttributedString {
        segments.reduce(into: AttributedString()) { text, segment in
            var part = AttributedString(segment.text)
            if segment.isMatch {
                part.backgroundColor = Color(theme.searchHighlight)
                part.inlinePresentationIntent = .stronglyEmphasized
            }
            text += part
        }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
