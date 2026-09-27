import BibleCore
import CoreTransferable
import SwiftUI

/// Вікно «Порівняти» (FR-36): виділені вірші в кожному перекладі, окремою панеллю.
/// Панелі закриваються (×), повертаються через «+ Переклад» і переставляються ◀ ▶ або перетягуванням;
/// набір і порядок зберігаються в налаштуваннях.
struct CompareView: View {
    let request: CompareRequest
    let model: ReaderViewModel
    @Bindable var preferences: PreferencesStore
    @State private var loaded: Result<[ComparePanel], any Error>?
    @Environment(\.theme) private var theme
    @Environment(\.interfaceScale) private var scale

    private var panels: ComparePanels {
        get { preferences.preferences.comparePanels }
        nonmutating set { preferences.preferences.comparePanels = newValue }
    }

    var body: some View {
        Group {
            switch loaded {
            case nil:
                ProgressView()
            case .success(let panels):
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(panels) { panel in
                            panelView(panel)
                        }
                    }
                    .padding(12)
                }
            case .failure(let error):
                MessageView(title: "Не вдалося завантажити вірші", systemImage: "exclamationmark.triangle",
                            lines: [error.localizedDescription])
            }
        }
        .frame(minWidth: 480, minHeight: 280)
        // База читається лише при зміні набору чи порядку панелей, а не на кожен рендер.
        .task(id: panels) { loaded = Result { try model.compare(request, panels: panels) } }
        .background(ThemeBackground())
        .navigationTitle(title)
        .toolbar {
            ToolbarItem {
                Menu {
                    ForEach(panels.hidden, id: \.self) { translation in
                        Button(translation.menuTitle) { panels.add(translation) }
                    }
                } label: {
                    Label("Переклад", systemImage: "plus")
                }
                .disabled(panels.hidden.isEmpty)
                .help("Повернути закриту панель")
                .accessibilityIdentifier("compare-add")
            }
        }
    }

    /// Назва книги мовою першої панелі: не змінюється, коли в головному вікні перемкнули переклад.
    private var title: String {
        let name = Book(number: request.book)?.name(in: panels.visible[0]) ?? ""
        return "Порівняти: \(name) \(request.chapter)"
    }

    private func panelView(_ panel: ComparePanel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(panel.translation.title).font(.system(size: scale.systemFontSize, weight: .semibold))
                    Text(panel.reference).font(.system(size: scale.systemFontSize * 0.9))
                        .foregroundStyle(Color(theme.secondaryText))
                }
                Spacer(minLength: 8)
                Button("Ліворуч", systemImage: "chevron.left") { panels.moveLeft(panel.translation) }
                    .disabled(!panels.canMoveLeft(panel.translation))
                    .accessibilityIdentifier("compare-left-\(panel.translation.rawValue)")
                Button("Праворуч", systemImage: "chevron.right") { panels.moveRight(panel.translation) }
                    .disabled(!panels.canMoveRight(panel.translation))
                    .accessibilityIdentifier("compare-right-\(panel.translation.rawValue)")
                Button("Закрити", systemImage: "xmark") { panels.close(panel.translation) }
                    .disabled(!panels.canClose)
                    .accessibilityIdentifier("compare-close-\(panel.translation.rawValue)")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            // Тягнемо за заголовок: тіло панелі — кнопка переходу, і drag з неї конфліктував би з кліком.
            .draggable(PanelDrag(translation: panel.translation))
            if panel.numberingMayDiffer {
                Label("Нумерація може відрізнятися", systemImage: "exclamationmark.circle")
                    .font(.system(size: scale.systemFontSize * 0.85))
                    .foregroundStyle(Color(theme.secondaryText))
            }
            Button {
                // Клік відкриває це місце в головному вікні в цьому перекладі. Якщо нумерація може відрізнятися,
                // відкриваємо розділ без фокусу на вірші: номер міг би вказати на інший вірш.
                model.open(Location(book: request.book, chapter: request.chapter), in: panel.translation,
                           focus: panel.numberingMayDiffer ? nil : request.verses.first)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    if panel.verses.isEmpty {
                        Text("Немає цих віршів у перекладі").foregroundStyle(Color(theme.secondaryText))
                    }
                    ForEach(panel.verses) { verse in
                        (Text("\(verse.verse) ").foregroundStyle(Color(theme.verseNumber)) + Text(verse.text))
                            .font(theme.verseFont(size: preferences.preferences.verseFontSize))
                            .foregroundStyle(Color(theme.text))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Відкрити в перекладі \(panel.translation.title)")
            .accessibilityHint("Відкрити в головному вікні")
        }
        .padding(12)
        .frame(width: 260, alignment: .topLeading)
        .background(Color(theme.sidebar), in: RoundedRectangle(cornerRadius: 8))
        .dropDestination(for: PanelDrag.self) { items, _ in
            guard let dragged = items.first else { return false }
            return panels.move(dragged.translation, to: panel.translation)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(panel.translation.title)
        .accessibilityIdentifier("compare-panel-\(panel.translation.rawValue)")
    }
}

/// Панель, яку перетягують. Передається рядком із префіксом: текст з інших програм без префікса не
/// розпізнається, тож не переставляє панелі (власний UTType вимагав би окремого Info.plist).
struct PanelDrag: Transferable {
    static let prefix = "bible-reader-panel:"
    struct NotAPanel: Error {}

    let translation: BibleCore.Translation

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: { prefix + $0.translation.rawValue }, importing: { (text: String) in
            guard text.hasPrefix(prefix), let translation = BibleCore.Translation(rawValue: String(text.dropFirst(prefix.count)))
            else { throw NotAPanel() }
            return PanelDrag(translation: translation)
        })
    }
}
