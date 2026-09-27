import AppKit
import BibleCore
import SwiftUI

struct ChapterView: View {
    let model: ReaderViewModel
    let fontSize: Double
    @State private var selection = Set<Int>()
    /// Після переходу до вірша фокус у списку, щоб ⌘C копіював цитату, а не текст запиту.
    @FocusState private var listFocused: Bool

    private var title: String {
        let name = Book(number: model.location.book)?.name(in: model.translation) ?? ""
        return "\(name) \(model.location.chapter)"
    }

    var body: some View {
        ScrollViewReader { proxy in
            List(selection: $selection) {
                ForEach(model.verses) { verse in
                    VerseRow(verse: verse, isFocused: verse.verse == model.focusedVerse, fontSize: fontSize)
                        // Праве поле завжди, щоб кнопка копіювання не перекривала текст і рядки не перескакували.
                        .padding(.trailing, 36)
                        .overlay(alignment: .topTrailing) {
                            if verse.verse == CopyButtonModel.anchorVerse(for: selection) {
                                CopyButton { copy(selection) }
                            }
                        }
                        .tag(verse.verse)
                        .id(verse.verse)
                }
            }
            .focused($listFocused)
            .navigationTitle(title)
            .contextMenu(forSelectionType: Int.self) { verses in
                Button("Копіювати") { copy(verses) }.disabled(verses.isEmpty)
            }
            .onCopyCommand {
                guard let quote = model.quote(for: selection) else { return [] }
                return [NSItemProvider(object: quote as NSString)]
            }
            .onChange(of: model.location) { _, _ in selection = [] }
            .onChange(of: model.focusRequest, initial: true) { _, _ in
                guard let verse = model.takeFocus() else { return }
                selection = [verse]
                listFocused = true
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
    let fontSize: Double

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(verse.verse)")
                .font(.system(size: fontSize * 0.75).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 24, alignment: .trailing)
            Text(verse.text)
                .font(.system(size: fontSize))
                .fontWeight(isFocused ? .semibold : .regular)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("verse-\(verse.verse)")
    }
}
