import BibleCore
import SwiftUI

struct SearchResultsView: View {
    let model: ReaderViewModel
    let results: [SearchResult]

    var body: some View {
        if results.isEmpty {
            ContentUnavailableView(
                "Нічого не знайдено",
                systemImage: "magnifyingglass",
                description: Text("За запитом «\(model.submittedQuery)» в перекладі \(model.translation.title) немає віршів."))
        } else {
            List(results) { result in
                Button { model.open(result) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Reference(book: result.verse.book, chapter: result.verse.chapter, verseStart: result.verse.verse)
                            .format(in: result.verse.translation))
                            .font(.headline)
                        Text(highlighted(result.segments))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Знайдено: \(results.count)")
        }
    }

    private func highlighted(_ segments: [SearchResult.Segment]) -> AttributedString {
        segments.reduce(into: AttributedString()) { text, segment in
            var part = AttributedString(segment.text)
            if segment.isMatch {
                part.backgroundColor = .yellow.opacity(0.4)
                part.inlinePresentationIntent = .stronglyEmphasized
            }
            text += part
        }
    }
}
