import BibleCore
import SwiftUI

/// The visit history column to the right of the reading area (FR-42): a flat list of recent verses, newest first.
/// A separate column, not an overlay, so the selection highlight and the selection buttons never cover a row.
struct HistoryPanel: View {
    let model: ReaderViewModel
    let open: (VisitEntry) -> Void
    @Environment(\.theme) private var theme
    @Environment(\.interfaceScale) private var scale

    static func width(for scale: InterfaceScale) -> CGFloat { 200 * scale.factor }

    var body: some View {
        let entries = model.historyEntries
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Історія").font(.system(size: scale.systemFontSize * 1.2, weight: .semibold))
                Spacer()
                Button("Очистити історію", systemImage: "trash") { model.clearHistory() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .disabled(entries.isEmpty)
                    .help("Очистити історію")
                    .accessibilityIdentifier("history-clear")
            }
            if entries.isEmpty {
                Text("Тут з’являться місця, які ви відвідали")
                    .foregroundStyle(Color(theme.secondaryText))
                    .accessibilityIdentifier("history-empty")
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(entries) { entry in
                        Button { open(entry) } label: {
                            Text(entry.title)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("\(entry.title) — \(entry.translation.title)")
                        .accessibilityLabel(entry.title)
                        .accessibilityIdentifier("history-row")
                    }
                }
            }
        }
        .font(.system(size: scale.systemFontSize))
        .foregroundStyle(Color(theme.text))
        .padding(12)
        .frame(width: Self.width(for: scale))
        .background(ThemeBackground())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history-panel")
    }
}

/// The toolbar toggle: with Drafts or Illustrations open the panel hides, and this shows it next to them (FR-42).
/// Without such a panel the history is always visible, so the toggle has nothing to switch.
struct HistoryToolbarButton: View {
    let model: ReaderViewModel
    let scale: InterfaceScale
    @Environment(DraftStore.self) private var drafts
    @AppStorage(HistoryLayout.alongsidePanelsKey) private var alongsidePanels = false

    private var sidePanelOpen: Bool { HistoryLayout.sidePanelOpen(drafts: drafts, model: model) }

    var body: some View {
        Button(alongsidePanels ? "Сховати історію" : "Показати історію",
               systemImage: sidePanelOpen && alongsidePanels ? "clock.fill" : "clock") {
            alongsidePanels.toggle()
        }
        .disabled(!sidePanelOpen)
        .help(sidePanelOpen ? "Історія поруч із чорнетками й ілюстраціями" : "Історія завжди видна, коли праворуч немає чорнеток чи ілюстрацій")
        .accessibilityIdentifier("history-toolbar")
        .controlSize(scale.controlSize)
    }
}

enum HistoryLayout {
    static let alongsidePanelsKey = "historyAlongsidePanels"

    @MainActor static func sidePanelOpen(drafts: DraftStore, model: ReaderViewModel) -> Bool {
        drafts.isOpen || model.illustrations != nil
    }
}
