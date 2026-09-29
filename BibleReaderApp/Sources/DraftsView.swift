import AppKit
import BibleCore
import SwiftUI
import UniformTypeIdentifiers

/// Панель «Чорнетки» праворуч від тексту (FR-38…FR-40): список або редактор активної чорнетки.
struct DraftsPanel: View {
    @Bindable var store: DraftStore
    let model: ReaderViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if let draft = store.active {
                DraftEditor(store: store, model: model, draft: draft)
                    .id(draft.id)
            } else {
                DraftList(store: store, model: model)
            }
        }
        .background(ThemeBackground())
        .foregroundStyle(Color(theme.text))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("drafts-panel")
    }
}

/// Список чорнеток: пошук, «Нова чорнетка», «Нова проповідь», фільтр за віршем.
struct DraftList: View {
    @Bindable var store: DraftStore
    let model: ReaderViewModel
    @State private var query = ""
    @Environment(\.theme) private var theme
    @Environment(\.interfaceScale) private var scale

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Чорнетки").font(.system(size: scale.systemFontSize * 1.4, weight: .semibold))
                Spacer()
                Button("Закрити чорнетки", systemImage: "xmark") { store.isOpen = false }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    // У режимі «Проповідь» Esc належить йому: панель під ним лишається відкритою.
                    .keyboardShortcut(store.isPresenting ? nil : .cancelAction)
                    .accessibilityIdentifier("drafts-close")
            }
            HStack {
                Button("Нова чорнетка", systemImage: "square.and.pencil") { store.create() }
                    .accessibilityIdentifier("drafts-new")
                Button("Нова проповідь", systemImage: "list.bullet.rectangle") { store.createSermon() }
                    .accessibilityIdentifier("drafts-new-sermon")
            }
            TextField("Пошук у чорнетках", text: $query)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("drafts-search")
            if let key = store.mentionFilter {
                HStack {
                    Text("Згадують \(model.localReference(book: key.book, chapter: key.chapter, verse: key.verse).format(in: model.translation))")
                    Button("Усі чорнетки", systemImage: "xmark.circle.fill") { store.mentionFilter = nil }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                }
                .foregroundStyle(Color(theme.secondaryText))
            }
            let drafts = store.list(matching: query)
            if drafts.isEmpty {
                Text(store.drafts.isEmpty ? "Ще немає чорнеток" : "Нічого не знайдено")
                    .foregroundStyle(Color(theme.secondaryText))
                    .accessibilityIdentifier("drafts-empty")
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(drafts) { draft in
                        Button { store.activeID = draft.id } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(draft.displayTitle).font(.system(size: scale.systemFontSize * 1.1, weight: .semibold))
                                Text(draft.updated.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: scale.systemFontSize * 0.85))
                                    .foregroundStyle(Color(theme.secondaryText))
                                if !draft.preview.isEmpty {
                                    Text(draft.preview).lineLimit(2).foregroundStyle(Color(theme.secondaryText))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(theme.results).opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("draft-row")
                    }
                }
            }
        }
        .padding(16)
    }
}

/// Редактор чорнетки: назва, Markdown-текст із кнопками форматування, живі посилання, перегляд, меню дій.
struct DraftEditor: View {
    @Bindable var store: DraftStore
    let model: ReaderViewModel
    let draft: Draft
    @State private var title = ""
    @State private var text = ""
    @State private var previewing = false
    @State private var confirmDelete = false
    @State private var editor = MarkdownEditorController()
    @Environment(\.theme) private var theme
    @Environment(\.interfaceScale) private var scale

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button("Чорнетки", systemImage: "chevron.left") { store.activeID = nil }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("draft-back")
                Spacer()
                Picker("Вигляд", selection: $previewing) {
                    Text("Редагувати").tag(false)
                    Text("Перегляд").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier("draft-mode")
                Button("Проповідь", systemImage: "play.rectangle") { store.isPresenting = true }
                    .help("Лише текст великим шрифтом на все вікно (Esc — назад)")
                    .accessibilityIdentifier("draft-present")
                actions
                Button("Закрити чорнетки", systemImage: "xmark") { store.isOpen = false }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    // У режимі «Проповідь» Esc належить йому: панель під ним лишається відкритою.
                    .keyboardShortcut(store.isPresenting ? nil : .cancelAction)
                    .accessibilityIdentifier("drafts-close")
            }
            TextField("Назва", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: scale.systemFontSize * 1.4, weight: .semibold))
                .accessibilityIdentifier("draft-title")
            if previewing {
                ScrollView {
                    DraftDocument(text: text, fontSize: scale.systemFontSize * 1.1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                formatting
                // Ідентифікатор `draft-text` — на самому NSTextView: на обгортці-прокрутці XCUI не бачив тексту (CI).
                MarkdownEditor(text: $text, controller: editor, fontSize: scale.systemFontSize * 1.1, theme: theme)
                references
            }
        }
        .padding(16)
        .environment(\.openURL, OpenURLAction { url in open(url) })
        .onAppear {
            title = draft.title
            text = draft.text
        }
        // Автозбереження: кожна зміна одразу в базі користувача.
        .onChange(of: title) { _, title in store.update(draft.id, title: title) }
        .onChange(of: text) { _, text in store.update(draft.id, text: text) }
        // «В чорнетку» дописує в сховище, поки редактор відкритий: підтягуємо текст.
        .onChange(of: store.active?.text) { _, stored in
            if let stored, stored != text { text = stored }
        }
        .confirmationDialog("Видалити «\(draft.displayTitle)»?", isPresented: $confirmDelete) {
            Button("Видалити", role: .destructive) { store.delete(draft.id) }
                .accessibilityIdentifier("draft-delete-confirm")
        }
    }

    private var actions: some View {
        Menu {
            Button("Скопіювати все") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(currentDraft.markdown, forType: .string)
            }
            Button("Зберегти як Markdown…") {
                FileExport.save(name: currentDraft.displayTitle + ".md", type: UTType(filenameExtension: "md") ?? .plainText) {
                    Data(currentDraft.markdown.utf8)
                }
            }
            Button("Друкувати / PDF…") { DraftPrinter.print(currentDraft) }
            Divider()
            Button("Видалити…", role: .destructive) { confirmDelete = true }
        } label: {
            Label("Дії", systemImage: "ellipsis.circle")
        }
        .labelStyle(.iconOnly)
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityIdentifier("draft-actions")
    }

    private var currentDraft: Draft { store.active ?? draft }

    private var formatting: some View {
        HStack(spacing: 4) {
            Button("Заголовок", systemImage: "number") { editor.prefixLines("## ") }
            Button("Список", systemImage: "list.bullet") { editor.prefixLines("- ") }
            Button("Жирний", systemImage: "bold") { editor.wrap("**") }
            Button("Курсив", systemImage: "italic") { editor.wrap("*") }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    /// Живі посилання під текстом: клік відкриває місце ліворуч, підказка — текст вірша.
    @ViewBuilder private var references: some View {
        let found = DraftReferences.find(in: text)
        if !found.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(Array(found.enumerated()), id: \.offset) { _, item in
                        Button(String(text[item.range])) { openReference(item.reference) }
                            .buttonStyle(.link)
                            .help(model.text(of: item.reference) ?? "")
                            .accessibilityIdentifier("draft-reference")
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("draft-references")
        }
    }

    private func open(_ url: URL) -> OpenURLAction.Result {
        guard let reference = DraftRendering.reference(fromLink: url.absoluteString) else { return .systemAction }
        openReference(reference)
        return .handled
    }

    private func openReference(_ reference: Reference) {
        model.openCanonical(book: reference.book, chapter: reference.chapter, verse: reference.verseStart)
    }
}

/// Текст чорнетки з форматуванням: заголовки, списки, жирний, курсив, посилання (перегляд і «Проповідь»).
struct DraftDocument: View {
    let text: String
    let fontSize: Double
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: fontSize * 0.5) {
            ForEach(Array(DraftRendering.blocks(text).enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let inline):
                    Self.inline(inline).font(.system(size: fontSize * [1.6, 1.35, 1.15][level - 1], weight: .bold))
                case .bullet(let inline):
                    HStack(alignment: .firstTextBaseline, spacing: fontSize * 0.4) {
                        Text("•")
                        Self.inline(inline)
                    }
                    .font(.system(size: fontSize))
                case .paragraph(let inline):
                    Self.inline(inline).font(.system(size: fontSize))
                case .spacer:
                    Spacer().frame(height: fontSize * 0.3)
                }
            }
        }
        .tint(Color(theme.accent))
        .textSelection(.enabled)
    }

    static func inline(_ markdown: String) -> Text {
        let attributed = (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(markdown)
        return Text(attributed)
    }
}

/// Режим «Проповідь» (FR-40): лише текст активної чорнетки великим шрифтом; ⌘+ / ⌘− — розмір, Esc — назад.
struct SermonView: View {
    @Bindable var store: DraftStore
    let model: ReaderViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(store.active?.displayTitle ?? "").font(.system(size: store.sermonFontSize * 1.4, weight: .bold))
                DraftDocument(text: store.active?.text ?? "", fontSize: store.sermonFontSize)
            }
            .frame(maxWidth: store.sermonFontSize * 36, alignment: .leading)
            .padding(48)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(Color(theme.text))
        .background(ThemeBackground())
        .overlay(alignment: .topTrailing) {
            HStack {
                // ⌘+ / ⌘− — у меню «Вигляд» (FontCommands): у цьому режимі вони змінюють цей шрифт.
                Button("Менший шрифт", systemImage: "textformat.size.smaller") { store.changeSermonFont(by: -2) }
                Button("Більший шрифт", systemImage: "textformat.size.larger") { store.changeSermonFont(by: 2) }
                Button("Вийти з режиму «Проповідь»", systemImage: "xmark") { store.isPresenting = false }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("sermon-close")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .padding(12)
        }
        .environment(\.openURL, OpenURLAction { url in
            guard let reference = DraftRendering.reference(fromLink: url.absoluteString) else { return .systemAction }
            store.isPresenting = false
            model.openCanonical(book: reference.book, chapter: reference.chapter, verse: reference.verseStart)
            return .handled
        })
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sermon-mode")
    }
}

/// Друк чорнетки; «Зберегти як PDF» — у системному діалозі друку (FR-40).
enum DraftPrinter {
    @MainActor static func print(_ draft: Draft) {
        let body = NSMutableAttributedString()
        let base = NSFont.systemFontSize + 1
        body.append(NSAttributedString(string: draft.displayTitle + "\n\n", attributes: [.font: NSFont.boldSystemFont(ofSize: base * 1.6)]))
        for block in DraftRendering.blocks(draft.text) {
            switch block {
            case .heading(let level, let inline): body.append(line(inline, size: base * [1.5, 1.3, 1.1][level - 1], bold: true))
            case .bullet(let inline): body.append(line("• " + inline, size: base, bold: false))
            case .paragraph(let inline): body.append(line(inline, size: base, bold: false))
            case .spacer: body.append(NSAttributedString(string: "\n"))
            }
        }
        let info = NSPrintInfo.shared
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: info.paperSize.width - info.leftMargin - info.rightMargin, height: 1))
        view.textStorage?.setAttributedString(body)
        view.sizeToFit()
        NSPrintOperation(view: view, printInfo: info).run()
    }

    private static func line(_ inline: String, size: CGFloat, bold: Bool) -> NSAttributedString {
        let parsed = (try? NSMutableAttributedString(markdown: inline, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? NSMutableAttributedString(string: inline)
        parsed.addAttribute(.font, value: bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size),
                            range: NSRange(location: 0, length: parsed.length))
        parsed.append(NSAttributedString(string: "\n"))
        return parsed
    }
}

/// Команди редактору: форматування діє на виділений текст (TextEditor на macOS 14 не дає доступу до виділення).
@MainActor
final class MarkdownEditorController {
    weak var textView: NSTextView?

    /// `**виділене**`; без виділення — `****` з курсором посередині.
    func wrap(_ marker: String) {
        guard let textView else { return }
        let range = textView.selectedRange()
        let selected = (textView.string as NSString).substring(with: range)
        replace(range, with: marker + selected + marker, in: textView)
        textView.setSelectedRange(NSRange(location: range.location + marker.utf16.count, length: selected.utf16.count))
    }

    /// Префікс на початку кожного рядка виділення (заголовок, список).
    func prefixLines(_ prefix: String) {
        guard let textView else { return }
        let string = textView.string as NSString
        let lines = string.lineRange(for: textView.selectedRange())
        let text = string.substring(with: lines)
        let prefixed = text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            .map { index, line in line.isEmpty && index > 0 ? String(line) : prefix + line }
            .joined(separator: "\n")
        replace(lines, with: prefixed, in: textView)
    }

    private func replace(_ range: NSRange, with text: String, in textView: NSTextView) {
        guard textView.shouldChangeText(in: range, replacementString: text) else { return }
        textView.replaceCharacters(in: range, with: text)
        textView.didChangeText()
    }
}

/// Редактор Markdown на `NSTextView`: undo, перевірка правопису, форматування виділеного.
struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    let controller: MarkdownEditorController
    let fontSize: Double
    let theme: ThemeTokens

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let textView = scroll.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.setAccessibilityIdentifier("draft-text")
        scroll.drawsBackground = false
        textView.drawsBackground = false
        controller.textView = textView
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let textView = scroll.documentView as! NSTextView
        context.coordinator.text = $text
        if textView.string != text { textView.string = text }
        textView.font = .systemFont(ofSize: fontSize)
        textView.textColor = NSColor(theme.text)
        textView.insertionPointColor = NSColor(theme.text)
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}

/// Збереження у файл, обраний користувачем (FR-24, FR-40).
enum FileExport {
    @MainActor static func save(name: String, type: UTType, contents: () throws -> Data) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [type]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try contents().write(to: url, options: .atomic)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

/// «В чорнетку» на виділенні (FR-38).
struct DraftButton: View {
    let action: () -> Void
    @State private var added = false

    var body: some View {
        SelectionButton(title: added ? "Додано" : "В чорнетку", systemImage: added ? "checkmark" : "square.and.pencil",
                        help: "Додати цитату в чорнетку", identifier: "draft-button") {
            action()
            added = true
        }
        .task(id: added) {
            guard added else { return }
            try? await Task.sleep(for: CopyButtonModel.feedbackDuration)
            added = false
        }
    }
}
