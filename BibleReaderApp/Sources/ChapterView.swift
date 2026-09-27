import AppKit
import QuartzCore
import BibleCore
import SwiftUI

struct ChapterView: View {
    let model: ReaderViewModel
    let fontSize: Double
    @State private var selection = Set<Int>()
    /// Вірш, нотатку до якого редагують.
    @State private var editingNote: VerseKey?
    @Environment(UserData.self) private var userData
    /// Після переходу до вірша фокус у списку, щоб ⌘C копіював цитату, а не текст запиту.
    @FocusState private var listFocused: Bool
    @Environment(\.theme) private var theme
    @Environment(\.interfaceScale) private var scale

    private var title: String {
        let name = Book(number: model.location.book)?.name(in: model.translation) ?? ""
        return "\(name) \(model.location.chapter)"
    }

    var body: some View {
        let marks = userData.marks(book: model.location.book, chapter: model.location.chapter)
        ScrollViewReader { proxy in
            List(selection: $selection) {
                ForEach(model.verses) { verse in
                    VerseRow(verse: verse, isFocused: verse.verse == model.focusedVerse, fontSize: fontSize,
                             marks: marks[verse.verse] ?? VerseMarks(), openNote: { editingNote = key(verse.verse) })
                        // Широке праве поле лише в рядку з кнопкою копіювання, інакше вузьке вікно втрачає чверть ширини.
                        .padding(.trailing, verse.verse == CopyButtonModel.anchorVerse(for: selection) ? CopyButton.width(for: scale) + 8 : 36)
                        .overlay(alignment: .topTrailing) {
                            if verse.verse == CopyButtonModel.anchorVerse(for: selection) {
                                // Виділення на момент рендеру: клік по кнопці в рядку не має звузити його до одного вірша.
                                CopyButton { [verses = selection] in copy(verses) }
                            }
                        }
                        .listRowBackground(rowBackground(verse.verse, marks[verse.verse]?.highlight))
                        .listRowSeparator(.hidden)
                        .tag(verse.verse)
                        .id(verse.verse)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ThemeBackground())
            .focused($listFocused)
            .navigationTitle(title)
            .contextMenu(forSelectionType: Int.self) { verses in
                Button("Копіювати") { copy(verses) }.disabled(verses.isEmpty)
                if let first = verses.min() {
                    Divider()
                    let target = Bookmark.Target(book: model.location.book, chapter: model.location.chapter, verse: first)
                    // Закладка ставиться на перший виділений вірш — так і написано в пункті.
                    Button(userData.isBookmarked(target) ? "Прибрати закладку з вірша \(first)" : "Додати закладку на вірш \(first)") {
                        userData.toggleBookmark(target)
                    }
                    Menu("Підсвітити") {
                        ForEach(HighlightColor.allCases, id: \.self) { color in
                            Button(color.title.capitalized) { userData.setHighlight(color, for: verses.map(key)) }
                        }
                        Divider()
                        Button("Прибрати підсвітку") { userData.setHighlight(nil, for: verses.map(key)) }
                    }
                    Button(userData.note(for: key(first)) == nil ? "Додати нотатку…" : "Редагувати нотатку…") {
                        editingNote = key(first)
                    }
                }
            }
            .sheet(item: $editingNote) { key in
                NoteEditor(key: key, translation: model.translation)
            }
            .onCopyCommand {
                guard let quote = model.quote(for: selection) else { return [] }
                return [NSItemProvider(object: quote as NSString)]
            }
            .onChange(of: model.location) { _, _ in selection = [] }
            .onAppear {
                // Після коміту першого кадру з віршами (NFR-3).
                CATransaction.setCompletionBlock { model.markFirstChapterShown() }
            }
            .onChange(of: model.focusRequest, initial: true) { _, _ in
                guard let verse = model.takeFocus() else { return }
                selection = [verse]
                listFocused = true
                DispatchQueue.main.async { proxy.scrollTo(verse, anchor: .top) }
            }
        }
    }

    private func key(_ verse: Int) -> VerseKey {
        VerseKey(book: model.location.book, chapter: model.location.chapter, verse: verse)
    }

    /// Виділення важливіше за підсвітку, щоб було видно, що саме виділено.
    private func rowBackground(_ verse: Int, _ highlight: HighlightColor?) -> Color {
        if selection.contains(verse) { return Color(theme.selection) }
        return highlight.map(Color.highlight) ?? .clear
    }

    private func copy(_ verses: Set<Int>) {
        guard let quote = model.quote(for: verses) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(quote, forType: .string)
    }
}

struct VerseRow: View {
    /// Підсвітка, закладка й нотатка для VoiceOver (текст вірша вже в label).
    var accessibilityMarks: String {
        var parts: [String] = []
        if let highlight = marks.highlight { parts.append("підсвітка: \(highlight.title)") }
        if marks.isBookmarked { parts.append("закладка") }
        if marks.hasNote { parts.append("є нотатка") }
        return parts.joined(separator: ", ")
    }

    let verse: Verse
    let isFocused: Bool
    let fontSize: Double
    var marks = VerseMarks()
    var openNote: () -> Void = {}
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(verse.verse)")
                    .font(.system(size: fontSize * 0.75).monospacedDigit())
                    .foregroundStyle(Color(theme.verseNumber))
                HStack(spacing: 2) {
                    if marks.isBookmarked {
                        Image(systemName: "bookmark.fill")
                            .accessibilityLabel("Закладка")
                            .accessibilityIdentifier("bookmark-mark-\(verse.verse)")
                    }
                    if marks.hasNote {
                        Button(action: openNote) { Image(systemName: "note.text") }
                            .buttonStyle(.plain)
                            .help("Нотатка")
                            .accessibilityLabel("Нотатка")
                            .accessibilityIdentifier("note-mark-\(verse.verse)")
                    }
                }
                .font(.system(size: fontSize * 0.6))
                .foregroundStyle(Color(theme.accent))
            }
            .frame(minWidth: 24, alignment: .trailing)
            Text(verse.text)
                .font(theme.verseFont(size: fontSize))
                .fontWeight(isFocused ? .semibold : .regular)
                .foregroundStyle(Color(theme.text))
                .lineSpacing(fontSize * theme.lineSpacing)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        // Позначки — у кінці мітки: value рядка списку macOS не віддає ні VoiceOver, ні XCUI.
        .accessibilityLabel(accessibilityMarks.isEmpty ? "\(verse.verse) \(verse.text)" : "\(verse.verse) \(verse.text); \(accessibilityMarks)")
        .accessibilityIdentifier("verse-\(verse.verse)")
        .accessibilityAction(named: "Нотатка") { openNote() }
    }
}

extension Color {
    /// Напівпрозорі маркери: текст теми лишається читабельним і на світлих, і на темних темах.
    static func highlight(_ color: HighlightColor) -> Color {
        switch color {
        case .yellow: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.3)
        case .green: Color(red: 0.2, green: 0.8, blue: 0.3).opacity(0.25)
        case .blue: Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.25)
        case .pink: Color(red: 1.0, green: 0.4, blue: 0.7).opacity(0.25)
        }
    }
}

extension VerseKey: @retroactive Identifiable {
    public var id: Self { self }
}

/// Нотатка до вірша: порожній текст при збереженні видаляє її.
struct NoteEditor: View {
    let key: VerseKey
    let translation: BibleCore.Translation
    @Environment(UserData.self) private var userData
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Нотатка: \(key.reference.format(in: translation))").font(.headline)
            TextEditor(text: $text)
                .font(.body)
                .frame(minWidth: 380, minHeight: 160)
                .accessibilityIdentifier("note-text")
            HStack {
                if userData.note(for: key) != nil {
                    Button("Видалити", role: .destructive) {
                        userData.setNote("", for: key)
                        dismiss()
                    }
                }
                Spacer()
                Button("Скасувати") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Зберегти") {
                    userData.setNote(text, for: key)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("note-save")
            }
        }
        .padding(20)
        .onAppear { text = userData.note(for: key)?.text ?? "" }
    }
}
