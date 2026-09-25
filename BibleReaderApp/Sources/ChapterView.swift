import AppKit
import BibleCore
import SwiftUI

struct ChapterView: View {
    let model: ReaderViewModel
    @State private var selection = Set<Int>()

    private var title: String {
        let name = Book(number: model.location.book)?.name(in: model.translation) ?? ""
        return "\(name) \(model.location.chapter)"
    }

    var body: some View {
        ScrollViewReader { proxy in
            List(selection: $selection) {
                ForEach(model.verses) { verse in
                    VerseRow(verse: verse, isFocused: verse.verse == model.focusedVerse)
                        .tag(verse.verse)
                        .id(verse.verse)
                }
            }
            .navigationTitle(title)
            .contextMenu(forSelectionType: Int.self) { verses in
                Button("Копіювати") { copy(verses) }.disabled(verses.isEmpty)
            }
            .onCopyCommand {
                guard let quote = model.quote(for: selection) else { return [] }
                return [NSItemProvider(object: quote as NSString)]
            }
            .onChange(of: model.location) { _, _ in selection = [] }
            .onChange(of: model.focusedVerse, initial: true) { _, verse in
                guard let verse else { return }
                selection = [verse]
                DispatchQueue.main.async { proxy.scrollTo(verse, anchor: .top) }
            }
        }
    }

    private func copy(_ verses: Set<Int>) {
        guard let quote = model.quote(for: verses) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(quote, forType: .string)
    }
}

struct VerseRow: View {
    let verse: Verse
    let isFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(verse.verse)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 24, alignment: .trailing)
            Text(verse.text)
                .font(.body)
                .fontWeight(isFocused ? .semibold : .regular)
        }
        .padding(.vertical, 2)
    }
}
