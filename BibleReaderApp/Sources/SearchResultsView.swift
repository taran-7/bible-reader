import BibleCore
import SwiftUI

struct SearchResultsView: View {
    let model: ReaderViewModel
    let results: [SearchResult]
    @Environment(\.interfaceScale) private var scale
    @Environment(\.theme) private var theme

    var body: some View {
        if results.isEmpty {
            MessageView(
                title: "Нічого не знайдено",
                systemImage: "magnifyingglass",
                lines: ["За запитом «\(model.submittedQuery)» в перекладі \(model.translation.title) немає віршів."])
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(theme.results))
        } else {
            List(results) { result in
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
            .scrollContentBackground(.hidden)
            .background(Color(theme.results))
            .navigationTitle("Знайдено: \(results.count)")
        }
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
