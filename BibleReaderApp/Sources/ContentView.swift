import BibleCore
import SwiftUI

struct ContentView: View {
    @Bindable var model: ReaderViewModel
    let preferences: PreferencesStore
    @Environment(UserData.self) private var userData
    @Environment(DraftStore.self) private var drafts
    /// The selected verses for which the "Compare" translation picker is open.
    @State private var compareSelection: CompareSelection?

    private var scale: InterfaceScale { preferences.preferences.interfaceScale }

    var body: some View {
        content.modifier(ThemedScene(preferences: preferences))
        #if DEBUG
            .overlay(alignment: .bottomLeading) {
                // Debug only; VoiceOver in Debug will read this number, deliberately; Release does not have it.
                if let launchMilliseconds = model.launchMilliseconds {
                    Text(verbatim: String(launchMilliseconds))
                        .font(.system(size: 1))
                        .opacity(0.01)
                        .accessibilityIdentifier("launch-time")
                }
            }
        #endif
    }

    /// "Try again" only when the database opened but a chapter was not read (tech debt #11).
    private var retryAction: (() -> Void)? {
        guard model.canRetryLoad else { return nil }
        return { [model] in model.retryLoad() }
    }

    @ViewBuilder private var content: some View {
        if let error = model.loadError {
            DatabaseErrorView(message: error, retry: retryAction)
                .background(ThemeBackground())
        } else {
            NavigationSplitView {
                BookList(model: model, fontSize: preferences.preferences.bookListFontSize,
                         verseFontSize: preferences.preferences.verseFontSize)
                    .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            } detail: {
                Group {
                    if model.searchError != nil || model.results != nil {
                        SearchResultsView(model: model)
                    } else if let comparison = model.comparison {
                        CompareView(comparison: comparison, fontSize: preferences.preferences.verseFontSize,
                                    close: model.closeComparison,
                                    chooseTranslations: { compareSelection = CompareSelection(verses: comparison.highlighted) })
                    } else if drafts.isOpen {
                        // Text on the left, the draft on the right: the same divider as for illustrations.
                        IllustrationsSplit {
                            chapter
                        } illustrations: {
                            DraftsPanel(store: drafts, model: model)
                        }
                    } else if let request = model.illustrations {
                        // Text on the left narrow (35 %), illustrations on the right wider (65 %); the divider is draggable.
                        IllustrationsSplit {
                            chapter
                        } illustrations: {
                            IllustrationsView(request: request, close: model.closeIllustrations)
                                .id(request)
                        }
                    } else {
                        chapter
                    }
                }
                .font(.system(size: scale.systemFontSize))
                .toolbar { ReaderToolbar(model: model, userData: userData, preferences: preferences, scale: scale) }
                .modifier(ToolbarTheme())
                .modifier(HiddenToolbarTitle())
            }
            .safeAreaInset(edge: .top) { UserDataWarning() }
            // One panel on the right: drafts close illustrations and vice versa.
            .onChange(of: drafts.isOpen) { _, open in if open { model.closeIllustrations() } }
            .onChange(of: model.illustrations) { _, request in if request != nil { drafts.isOpen = false } }
            // Under "Sermon" mode: no focus and no VoiceOver.
            .accessibilityHidden(drafts.isPresenting)
            .overlay {
                if drafts.isPresenting, drafts.isOpen, drafts.active != nil {
                    SermonView(store: drafts, model: model)
                }
            }
            .sheet(item: $compareSelection) { selection in
                CompareSetup(current: model.translation, preferences: preferences) { chosen in
                    model.showComparison(of: selection.verses, with: chosen)
                }
            }
            // The parallel translation from settings; the same as the main one means off.
            .onChange(of: [preferences.preferences.parallelTranslation, model.translation], initial: true) {
                let other = preferences.preferences.parallelTranslation
                model.parallelTranslation = other == model.translation ? nil : other
            }
            .modifier(SearchField(query: $model.query))
            .background(SearchFieldStyler())
            .onSubmit(of: .search) { model.submitSearch() }
            .onChange(of: model.query) { _, query in
                if query.isEmpty { model.submitSearch() }
            }
        }
    }
}

extension ContentView {
    private var chapter: some View {
        ChapterView(model: model, fontSize: preferences.preferences.verseFontSize) { verses in
            guard !verses.isEmpty else { return }
            compareSelection = CompareSelection(verses: verses)
        }
    }
}

struct CompareSelection: Identifiable {
    let verses: Set<Int>
    let id = UUID()
}

struct DatabaseErrorView: View {
    let message: String
    /// Present when the database opened but one page was not read (tech debt #11).
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            MessageView(
                title: retry == nil ? "Не вдалося відкрити базу" : "Не вдалося прочитати базу",
                systemImage: "exclamationmark.triangle",
                lines: retry == nil ? [message, "Перезберіть додаток після «make db»."] : [message])
            .textSelection(.enabled)
            if let retry {
                Button("Спробувати ще раз", action: retry)
                    .accessibilityIdentifier("database-retry")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("database-error")
    }
}

/// A user database error: without it, notes would be silently lost after a restart.
struct UserDataWarning: View {
    @Environment(UserData.self) private var userData
    @Environment(DraftStore.self) private var drafts

    var body: some View {
        // A draft that failed to save would otherwise vanish silently after a restart (add-sermon-drafts review).
        if let error = drafts.lastError, !userData.isInMemoryOnly {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("Не вдалося зберегти чорнетку: \(error)").textSelection(.enabled)
                Spacer()
                Button("Закрити") { drafts.dismissError() }
            }
            .padding(8)
            .background(.bar)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("drafts-error")
        }
        if let error = userData.lastError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(userData.isInMemoryOnly
                     ? "Закладки, нотатки й чорнетки не зберігаються: базу користувача не відкрито (\(error))."
                     : "Не вдалося зберегти зміну: \(error)")
                    .textSelection(.enabled)
                Spacer()
                if !userData.isInMemoryOnly {
                    Button("Закрити") { userData.dismissError() }
                }
            }
            .padding(8)
            .background(.bar)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("userdata-error")
        }
    }
}

/// The chapter title in the toolbar is shown by the chapter picker button; the system title in the toolbar is hidden,
/// while the window title stays (the Window menu, VoiceOver). On macOS 14 without the API both are visible.
struct HiddenToolbarTitle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.toolbar(removing: .title)
        } else {
            content
        }
    }
}

/// The search field in the toolbar center, not on the right (owner request 2026-09-28).
/// `.toolbarPrincipal` exists only in the SDK of new Xcode (Swift 6.2+); with an older one (CI on macos-15) the field is on the right.
struct SearchField: ViewModifier {
    @Binding var query: String

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        content.searchable(text: $query, placement: .toolbarPrincipal, prompt: "Слово або посилання (Ин 3:16)")
        #else
        content.searchable(text: $query, prompt: "Слово або посилання (Ин 3:16)")
        #endif
    }
}

/// AppKit draws the toolbar search field, and `.searchable` cannot set its font or colors:
/// we find the `NSSearchField` in the window toolbar and apply the interface scale and theme (tech debt #15, #18).
struct SearchFieldStyler: NSViewRepresentable {
    @Environment(\.theme) private var theme
    @Environment(\.interfaceScale) private var scale

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        let style = SearchFieldStyle(theme: theme, fontSize: scale.systemFontSize)
        // The toolbar appears after the first layout pass.
        DispatchQueue.main.async { Self.apply(style, in: view.window) }
    }

    static func apply(_ style: SearchFieldStyle, in window: NSWindow?) {
        guard let items = window?.toolbar?.items else { return }
        let fields = items.compactMap { item -> NSSearchField? in
            if let search = item as? NSSearchToolbarItem { return search.searchField }
            return item.view.flatMap(searchField(in:))
        }
        for field in fields {
            field.font = .systemFont(ofSize: style.fontSize)
            field.textColor = NSColor(style.text)
            field.backgroundColor = NSColor(style.background)
            field.drawsBackground = true
            field.appearance = NSAppearance(named: style.colorScheme == .dark ? .darkAqua : .aqua)
            field.invalidateIntrinsicContentSize()
        }
    }

    private static func searchField(in view: NSView) -> NSSearchField? {
        if let field = view as? NSSearchField { return field }
        return view.subviews.lazy.compactMap(searchField(in:)).first
    }
}

extension NSColor {
    convenience init(_ color: ThemeColor) {
        self.init(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1)
    }
}

/// Chapter text and the illustrations panel side by side: the default text share is 35 %, the divider is draggable
/// and remembered (`HSplitView` does not set the initial share).
struct IllustrationsSplit<Text: View, Illustrations: View>: View {
    @ViewBuilder let text: Text
    @ViewBuilder let illustrations: Illustrations
    @AppStorage("illustrationsTextFraction") private var fraction = 0.35
    @State private var dragStart: Double?
    @State private var cursorPushed = false


    private func setResizeCursor(_ on: Bool) {
        guard on != cursorPushed else { return }
        if on { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
        cursorPushed = on
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            HStack(spacing: 0) {
                // The value from defaults may be corrupted: the same limits as when dragging.
                text.frame(width: width * min(max(fraction, 0.2), 0.7))
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1)
                    .padding(.horizontal, 3)
                    .contentShape(Rectangle())
                    .onHover { inside in setResizeCursor(inside) }
                    // The panel was closed with Esc while the cursor was over the divider: without this "↔" would stay.
                    .onDisappear { setResizeCursor(false) }
                    .gesture(DragGesture(minimumDistance: 1)
                        .onChanged { drag in
                            let start = dragStart ?? fraction
                            dragStart = start
                            fraction = min(max(start + drag.translation.width / width, 0.2), 0.7)
                        }
                        .onEnded { _ in dragStart = nil })
                    .accessibilityHidden(true)
                illustrations.frame(maxWidth: .infinity)
            }
        }
    }
}
