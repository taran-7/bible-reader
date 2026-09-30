import BibleCore
import SwiftUI

/// "Compare" mode in the main window (FR-36): the whole chapter in columns by translation, rows aligned
/// by verse, selected verses highlighted and scrolled into view. ✕ or Esc return to reading.
struct CompareView: View {
    let comparison: Comparison
    let fontSize: Double
    let close: () -> Void
    let chooseTranslations: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.interfaceScale) private var scale

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(comparison.rows) { row in
                            rowView(row)
                                .id(row.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                // Both on first display and when "Translations…" replaced the comparison.
                .onChange(of: comparison.translations, initial: true) {
                    guard let first = comparison.highlighted.min() else { return }
                    // The verse before the selected one is also in frame: you see where the thought starts.
                    let target = comparison.rows.last { $0.id < first }?.id ?? first
                    DispatchQueue.main.async { proxy.scrollTo(target, anchor: .top) }
                }
            }
        }
        .background(ThemeBackground())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("compare-mode")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            ForEach(comparison.translations, id: \.self) { translation in
                VStack(alignment: .leading, spacing: 2) {
                    Text(comparison.title(of: translation))
                        .font(.system(size: scale.systemFontSize * 1.15, weight: .semibold))
                    Text(translation.title)
                        .font(.system(size: scale.systemFontSize * 0.9))
                        .foregroundStyle(Color(theme.secondaryText))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("compare-column-\(translation.rawValue)")
            }
            HStack(spacing: 4) {
                Button("Переклади…", systemImage: "checklist", action: chooseTranslations)
                    .help("Вибрати переклади")
                    .accessibilityIdentifier("compare-choose")
                Button("Закрити порівняння", systemImage: "xmark", action: close)
                    .keyboardShortcut(.cancelAction)
                    .help("Назад до читання (Esc)")
                    .accessibilityIdentifier("compare-close")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
        .foregroundStyle(Color(theme.text))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func rowView(_ row: CompareRow) -> some View {
        let highlighted = comparison.highlighted.contains(row.primary.verse)
        return HStack(alignment: .firstTextBaseline, spacing: 16) {
            column([row.primary])
            ForEach(Array(row.others.enumerated()), id: \.offset) { _, verses in column(verses) }
            // Under the header buttons, so the columns stand exactly under their titles.
            Color.clear.frame(width: 44 * scale.factor, height: 1)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(highlighted ? Color(theme.selection) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        // The selection mark goes into the identifier: macOS does not give a combined element's value to either VoiceOver or XCUI.
        .accessibilityIdentifier("compare-row-\(row.primary.verse)" + (highlighted ? "-selected" : ""))
        .accessibilityAddTraits(highlighted ? .isSelected : [])
    }

    /// An empty cell means the verse is merged with the previous one or has no counterpart.
    private func column(_ verses: [Verse]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(verses) { verse in
                (Text(ParallelColumn.label(verse, primaryChapter: comparison.location.chapter) + " ")
                    .foregroundStyle(Color(theme.verseNumber)) + Text(verse.text))
                    .font(theme.verseFont(size: fontSize))
                    .foregroundStyle(Color(theme.text))
                    .lineSpacing(fontSize * theme.lineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The translation picker for "Compare": checkboxes, the choice is remembered in settings.
/// The on-screen translation is always the first column, so it is not in the list.
struct CompareSetup: View {
    let current: BibleCore.Translation
    @Bindable var preferences: PreferencesStore
    let compare: ([BibleCore.Translation]) -> Void
    @Environment(\.dismiss) private var dismiss

    private var choices: [BibleCore.Translation] { BibleCore.Translation.allCases.filter { $0 != current } }
    private var chosen: [BibleCore.Translation] {
        preferences.preferences.comparePanels.visible.filter { $0 != current }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Порівняти з перекладами").font(.headline)
            ForEach(choices, id: \.self) { translation in
                Toggle(translation.menuTitle, isOn: Binding(
                    get: { chosen.contains(translation) },
                    set: { _ in preferences.preferences.comparePanels.toggle(translation) }))
                    .toggleStyle(.checkbox)
                    // The last selected one cannot be unchecked: there would be nothing to compare with.
                    .disabled(chosen == [translation])
                    .accessibilityIdentifier("compare-choice-\(translation.rawValue)")
            }
            HStack {
                Spacer()
                Button("Скасувати") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Порівняти") {
                    compare(chosen)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(chosen.isEmpty)
                .accessibilityIdentifier("compare-start")
            }
        }
        .padding(20)
        .frame(minWidth: 340)
    }
}
