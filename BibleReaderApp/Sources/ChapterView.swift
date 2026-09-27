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
    @Environment(\.openWindow) private var openWindow
    /// Після переходу до вірша фокус у списку, щоб ⌘C копіював цитату, а не текст запиту.
    @FocusState private var listFocused: Bool
    @Environment(\.theme) private var theme
    @Environment(\.interfaceScale) private var scale

    private var title: String {
        let name = Book(number: model.location.book)?.name(in: model.translation) ?? ""
        return "\(name) \(model.location.chapter)"
    }

    var body: some View {
        // Дані користувача в нумерації KJV: у Синодальному позначки стають на той самий зміст.
        let marks = Dictionary(uniqueKeysWithValues: model.verses.map { ($0.verse, userData.marks(for: model.canonicalKeys($0.verse))) })
        let parallel = Dictionary(uniqueKeysWithValues: model.parallelRows.map { ($0.primary.verse, $0.secondary) })
        ScrollViewReader { proxy in
            List(selection: $selection) {
                ForEach(model.verses) { verse in
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        VerseRow(verse: verse, isFocused: verse.verse == model.focusedVerse, fontSize: fontSize,
                                 marks: marks[verse.verse] ?? VerseMarks(), openNote: { editingNote = key(verse.verse) })
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let secondary = parallel[verse.verse], let other = model.parallelTranslation {
                            ParallelColumn(verses: secondary, translation: other, primaryChapter: model.location.chapter,
                                           fontSize: fontSize)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                        // Широке праве поле лише в рядку з кнопкою копіювання, інакше вузьке вікно втрачає чверть ширини.
                        .padding(.trailing, verse.verse == CopyButtonModel.anchorVerse(for: selection)
                                  ? CopyButton.width(for: scale) + CompareButton.width(for: scale) + 12 : 36)
                        .overlay(alignment: .topTrailing) {
                            if verse.verse == CopyButtonModel.anchorVerse(for: selection) {
                                // Виділення на момент рендеру: клік по кнопці в рядку не має звузити його до одного вірша.
                                HStack(spacing: 4) {
                                    CompareButton { [verses = selection] in compare(verses) }
                                    CopyButton { [verses = selection] in copy(verses) }
                                }
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
                Button("Порівняти в перекладах") { compare(verses) }.disabled(verses.isEmpty)
                if let first = verses.min() {
                    Divider()
                    let canonical = key(first)
                    let target = Bookmark.Target(book: canonical.book, chapter: canonical.chapter, verse: canonical.verse)
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
                NoteEditor(key: key, title: model.localReference(book: key.book, chapter: key.chapter, verse: key.verse)
                    .format(in: model.translation))
            }
            .onCopyCommand {
                guard let quote = model.quote(for: selection) else { return [] }
                return [NSItemProvider(object: quote as NSString)]
            }
            .onChange(of: model.location) { _, _ in selection = [] }
            // Той самий номер в іншому перекладі може означати інший зміст; вірш перевиділить фокус.
            .onChange(of: model.translation) { _, _ in selection = [] }
            // Перший виділений вірш: при перемиканні перекладу відкриється саме він (FR-27).
            .onChange(of: selection) { _, selection in model.anchorVerse = selection.min() }
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

    private func key(_ verse: Int) -> VerseKey { model.canonicalKey(verse) }

    /// Виділення важливіше за підсвітку, щоб було видно, що саме виділено.
    private func rowBackground(_ verse: Int, _ highlight: HighlightColor?) -> Color {
        if selection.contains(verse) { return Color(theme.selection) }
        return highlight.map(Color.highlight) ?? .clear
    }

    private func compare(_ verses: Set<Int>) {
        guard !verses.isEmpty else { return }
        openWindow(id: "compare", value: CompareRequest(book: model.location.book, chapter: model.location.chapter, verses: verses))
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
    /// Посилання мовою й нумерацією перекладу на екрані.
    let title: String
    @Environment(UserData.self) private var userData
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Нотатка: \(title)").font(.headline)
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

/// Друга колонка паралельного перегляду (FR-26): відповідні вірші іншого перекладу; якщо розділ інший —
/// номер із розділом. Порожньо — вірш злито з попереднім або відповідника немає.
struct ParallelColumn: View {
    let verses: [Verse]
    let translation: BibleCore.Translation
    let primaryChapter: Int
    let fontSize: Double
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(verses) { verse in
                (Text(label(verse) + " ").foregroundStyle(Color(theme.verseNumber)) + Text(verse.text))
                    .font(theme.verseFont(size: fontSize))
                    .foregroundStyle(Color(theme.text))
                    .lineSpacing(fontSize * theme.lineSpacing)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(translation.title): " + verses.map { "\(label($0)) \($0.text)" }.joined(separator: " "))
        .accessibilityIdentifier("parallel-\(verses.first.map { "\($0.chapter)-\($0.verse)" } ?? "empty")")
    }

    private func label(_ verse: Verse) -> String {
        verse.chapter == primaryChapter ? "\(verse.verse)" : "\(verse.chapter):\(verse.verse)"
    }
}
