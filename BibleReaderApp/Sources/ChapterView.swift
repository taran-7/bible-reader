import AppKit
import QuartzCore
import BibleCore
import SwiftUI

struct ChapterView: View {
    let model: ReaderViewModel
    let fontSize: Double
    /// "Compare" (FR-36): the translation picker and comparison mode live in `ContentView`.
    var compare: (Set<Int>) -> Void = { _ in }
    @State private var selection = Set<Int>()
    /// The text column width: in a narrow one the selection buttons show icons only.
    @State private var listWidth: CGFloat = 1000
    /// The verse whose note is being edited.
    @State private var editingNote: VerseKey?
    @Environment(UserData.self) private var userData
    @Environment(DraftStore.self) private var drafts
    /// After jumping to a verse, focus is in the list, so ⌘C copies the quote, not the query text.
    @FocusState private var listFocused: Bool
    @Environment(\.theme) private var theme
    @Environment(\.interfaceScale) private var scale

    private var title: String {
        let name = Book(number: model.location.book)?.name(in: model.translation) ?? ""
        return "\(name) \(model.location.chapter)"
    }

    var body: some View {
        // User data in KJV numbering: in the Synodal the marks land on the same content.
        let marks = Dictionary(uniqueKeysWithValues: model.verses.map { ($0.verse, userData.marks(for: model.canonicalKeys($0.verse))) })
        let parallel = Dictionary(uniqueKeysWithValues: model.parallelRows.map { ($0.primary.verse, $0.secondary) })
        let compactButtons = SelectionButton.isCompact(listWidth: listWidth, scale: scale, count: buttonCount)
        ScrollViewReader { proxy in
            List(selection: $selection) {
                ForEach(model.verses) { verse in
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        VerseRow(verse: verse, isFocused: verse.verse == model.focusedVerse, fontSize: fontSize,
                                 marks: marks[verse.verse] ?? VerseMarks(), openNote: { editingNote = key(verse.verse) },
                                 inDrafts: drafts.isMentioned(model.canonicalKeys(verse.verse)),
                                 openDrafts: { drafts.showMentions(of: model.canonicalKeys(verse.verse)) },
                                 parallelText: spokenParallel(parallel[verse.verse]))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let secondary = parallel[verse.verse], let other = model.parallelTranslation {
                            ParallelColumn(verses: secondary, translation: other, primaryChapter: model.location.chapter,
                                           fontSize: fontSize)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                        // One translation: a centered ~75-character column (FR-15): long lines are hard to read.
                        .frame(maxWidth: parallel.isEmpty ? ReadingPreferences.readingColumnWidth(fontSize: fontSize) : .infinity)
                        .frame(maxWidth: .infinity)
                        // A wide right margin only in the row with the copy button, otherwise a narrow window loses a quarter of its width.
                        // The same right margin in all rows: selection buttons do not overlap the text,
                        // and the selected verse does not shift (owner request 2026-09-28).
                        .padding(.trailing, SelectionButton.rowWidth(for: scale, compact: compactButtons, count: buttonCount))
                        .overlay(alignment: .topTrailing) {
                            if verse.verse == CopyButtonModel.anchorVerse(for: selection) {
                                // The selection at render time: a click on a button in a row must not narrow it to one verse.
                                HStack(spacing: SelectionButton.spacing) {
                                    IllustrationsButton { [verses = selection] in illustrations(verses) }
                                    CompareButton { [verses = selection] in compare(verses) }
                                    CopyButton { [verses = selection] in copy(verses) }
                                    if drafts.isOpen {
                                        DraftButton { [verses = selection] in addToDraft(verses) }
                                    }
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
            .environment(\.compactSelectionButtons, compactButtons)
            .background(GeometryReader { geometry in
                Color.clear.onAppear { listWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, width in listWidth = width }
            })
            .background(ThemeBackground())
            .focused($listFocused)
            // Esc is the Edit → Deselect menu item: works with any focus (FR-17).
            .onChange(of: model.clearSelectionRequest) { _, _ in selection = [] }
            .navigationTitle(title)
            .contextMenu(forSelectionType: Int.self) { verses in
                Button("Копіювати") { copy(verses) }.disabled(verses.isEmpty)
                Button("Порівняти в перекладах") { compare(verses) }.disabled(verses.isEmpty)
                Button("Пошук ілюстрацій") { illustrations(verses) }.disabled(verses.isEmpty)
                Button("В чорнетку") { addToDraft(verses) }.disabled(verses.isEmpty)
                if let first = verses.min() {
                    Divider()
                    let canonical = key(first)
                    let target = Bookmark.Target(book: canonical.book, chapter: canonical.chapter, verse: canonical.verse)
                    // The bookmark goes on the first selected verse, as the item says.
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
            // The same number in another translation may mean different content; the verse will re-select the focus.
            .onChange(of: model.translation) { _, _ in selection = [] }
            // The first selected verse: switching translation opens exactly this one (FR-27).
            .onChange(of: selection) { _, selection in model.anchorVerse = selection.min() }
            .onAppear {
                // After the first frame with verses is committed (NFR-3).
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

    private func spokenParallel(_ secondary: [Verse]?) -> String? {
        guard let secondary, let other = model.parallelTranslation else { return nil }
        return ParallelColumn.spoken(secondary, translation: other, primaryChapter: model.location.chapter)
    }

    /// Selection beats highlight, so it is visible what exactly is selected.
    private func rowBackground(_ verse: Int, _ highlight: HighlightColor?) -> Color {
        if selection.contains(verse) { return Color(theme.selection) }
        return highlight.map(Color.highlight) ?? .clear
    }

    /// Illustrations: a panel on the right in the same window.
    private func illustrations(_ verses: Set<Int>) {
        model.showIllustrations(for: verses)
    }

    /// "To draft" is shown only with the drafts panel open: otherwise a fourth button would take space in every row.
    private var buttonCount: Int { drafts.isOpen ? 4 : 3 }

    /// The same quote as copying, at the end of the active draft (FR-38).
    private func addToDraft(_ verses: Set<Int>) {
        guard let quote = model.quote(for: verses) else { return }
        drafts.append(quote)
    }

    private func copy(_ verses: Set<Int>) {
        guard let quote = model.quote(for: verses) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(quote, forType: .string)
    }
}

struct VerseRow: View {
    /// Highlight, bookmark and note for VoiceOver (the verse text is already in the label).
    var accessibilityMarks: String {
        var parts: [String] = []
        if let highlight = marks.highlight { parts.append("підсвітка: \(highlight.title)") }
        if marks.isBookmarked { parts.append("закладка") }
        if marks.hasNote { parts.append("є нотатка") }
        if inDrafts { parts.append("є в чорнетках") }
        return parts.joined(separator: ", ")
    }

    let verse: Verse
    let isFocused: Bool
    let fontSize: Double
    var marks = VerseMarks()
    var openNote: () -> Void = {}
    /// The verse is mentioned in a draft (FR-39): the marker leads to those drafts.
    var inDrafts = false
    var openDrafts: () -> Void = {}
    /// The second translation for VoiceOver: the row is read together with the parallel column.
    var parallelText: String?
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
                    if inDrafts {
                        Button(action: openDrafts) { Image(systemName: "square.and.pencil") }
                            .buttonStyle(.plain)
                            .help("Є в чорнетках")
                            .accessibilityLabel("Є в чорнетках")
                            .accessibilityIdentifier("draft-mark-\(verse.verse)")
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
        // Marks go at the end of the label: macOS does not give a list row's value to either VoiceOver or XCUI.
        .accessibilityLabel(["\(verse.verse) \(verse.text)", accessibilityMarks, parallelText ?? ""]
            .filter { !$0.isEmpty }.joined(separator: "; "))
        .accessibilityIdentifier("verse-\(verse.verse)")
        .accessibilityAction(named: "Нотатка") { openNote() }
    }
}

extension Color {
    /// Semi-transparent markers: the theme text stays readable on both light and dark themes.
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

/// A verse note: empty text on save deletes it.
struct NoteEditor: View {
    let key: VerseKey
    /// The reference in the on-screen translation's language and numbering.
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

/// The second column of the parallel view (FR-26): the corresponding verses of the other translation; if the chapter differs,
/// the number with the chapter. Empty means the verse is merged with the previous one or has no counterpart.
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
        // VoiceOver reads the column in the label of the main verse's row (`VerseRow.parallelText`).
        .accessibilityHidden(true)
    }

    private func label(_ verse: Verse) -> String { Self.label(verse, primaryChapter: primaryChapter) }

    static func label(_ verse: Verse, primaryChapter: Int) -> String {
        verse.chapter == primaryChapter ? "\(verse.verse)" : "\(verse.chapter):\(verse.verse)"
    }

    static func spoken(_ verses: [Verse], translation: BibleCore.Translation, primaryChapter: Int) -> String? {
        guard !verses.isEmpty else { return nil }
        return "\(translation.title): " + verses.map { "\(label($0, primaryChapter: primaryChapter)) \($0.text)" }.joined(separator: " ")
    }
}
