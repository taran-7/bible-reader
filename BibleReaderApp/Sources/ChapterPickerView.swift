import AppKit
import BibleCore
import SwiftUI

/// A book's chapter numbers in a popover (FR-37): beside the book in the sidebar
/// or below the chapter title in the toolbar. A click or arrows + Return open a chapter;
/// Esc, ✕ or a click outside close it without navigating.
struct ChapterPickerView: View {
    let model: ReaderViewModel
    let picker: ChapterPicker
    /// The verse font size: ⌘+ / ⌘− also enlarge chapter numbers (FR-15).
    let fontSize: Double
    @State private var cursor = 1
    @FocusState private var focused: Bool
    @Environment(\.theme) private var theme
    @Environment(\.interfaceScale) private var scale

    private var cellSize: CGFloat { fontSize * 44 / 15 }  // 44 pt at the default 15 pt

    /// All chapters without scrolling if the screen allows (Psalms is 15 rows);
    /// on a short screen the grid scrolls. The margin covers the window title, the Dock and the popover frame.
    private var maxGridHeight: CGFloat {
        let screen = NSScreen.main?.visibleFrame.height ?? 800
        return max(screen - 160 * scale.factor, 200)
    }

    var body: some View {
        card
        // A click on a book keeps focus in the list until the event ends; take it on the next cycle.
        .task(id: picker) {
            cursor = picker.initialCursor
            await Task.yield()
            focused = true
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10 * scale.factor) {
            HStack {
                Text(bookName)
                    .font(.system(size: fontSize + 2, weight: .semibold))
                    .foregroundStyle(Color(theme.text))
                Spacer()
                Button("Закрити", systemImage: "xmark") { model.dismissChapterPicker() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color(theme.secondaryText))
                    // Esc also when the grid has not received focus yet.
                    .keyboardShortcut(.cancelAction)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    grid
                }
                .frame(maxHeight: maxGridHeight)
                .fixedSize(horizontal: false, vertical: true)
                .onChange(of: cursor) { proxy.scrollTo(cursor) }
            }
        }
        .padding(16 * scale.factor)
        .fixedSize()
        .background(Color(theme.results))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Розділи: \(bookName)")
        .accessibilityIdentifier("chapter-picker")
    }

    /// Focus on the grid, not on the buttons: arrows move the cursor without Full Keyboard Access (NFR-4).
    private var grid: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(Array(stride(from: 1, through: picker.chapterCount, by: ChapterPicker.columns)), id: \.self) { first in
                GridRow {
                    ForEach(first...min(first + ChapterPicker.columns - 1, picker.chapterCount), id: \.self) { chapter in
                        chapterButton(chapter).id(chapter)
                    }
                }
            }
        }
        .padding(2)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress(.leftArrow) { step(-1) }
        .onKeyPress(.rightArrow) { step(1) }
        .onKeyPress(.upArrow) { step(-ChapterPicker.columns) }
        .onKeyPress(.downArrow) { step(ChapterPicker.columns) }
        .onKeyPress(.return) {
            model.pickChapter(cursor)
            return .handled
        }
        .onKeyPress(.escape) {
            model.dismissChapterPicker()
            return .handled
        }
    }

    private func step(_ delta: Int) -> KeyPress.Result {
        cursor = picker.move(cursor, by: delta)
        return .handled
    }

    private var bookName: String {
        model.books.first { $0.number == picker.book }?.name(in: model.translation) ?? ""
    }

    private func chapterButton(_ chapter: Int) -> some View {
        let isCurrent = chapter == picker.current
        return Button { model.pickChapter(chapter) } label: {
            Text(verbatim: String(chapter))
                .font(.system(size: fontSize, weight: isCurrent ? .semibold : .regular))
                .foregroundStyle(Color(theme.text))
                .frame(width: cellSize, height: cellSize * 0.8)
                .background(
                    isCurrent ? Color(theme.sidebarSelection) : Color(theme.secondaryText).opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 6))
                // The current one also gets a border, not just a background; the keyboard cursor gets an accent border.
                .overlay {
                    if focused && chapter == cursor {
                        RoundedRectangle(cornerRadius: 6).strokeBorder(Color(theme.accent), lineWidth: 2)
                    } else if isCurrent {
                        RoundedRectangle(cornerRadius: 6).strokeBorder(Color(theme.text).opacity(0.6), lineWidth: 1)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCurrent ? "Розділ \(chapter), поточний" : "Розділ \(chapter)")
        .accessibilityIdentifier("chapter-\(chapter)")
    }
}

extension ReaderViewModel {
    /// Showing the popover for a specific place: a book in the sidebar or the title in the toolbar.
    func chapterPickerBinding(book: Int, origin: ChapterPicker.Origin) -> Binding<Bool> {
        Binding(
            get: { self.chapterPicker.map { $0.book == book && $0.origin == origin } ?? false },
            set: { if !$0, self.chapterPicker?.origin == origin { self.dismissChapterPicker() } })
    }
}
