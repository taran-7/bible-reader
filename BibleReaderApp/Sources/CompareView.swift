import BibleCore
import SwiftUI

/// Режим «Порівняти» в головному вікні (FR-36): увесь розділ колонками по перекладах, рядки вирівняні
/// за віршами, виділені вірші підсвічені і прокручені у видиму частину. ✕ або Esc — назад до читання.
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
                .onAppear {
                    guard let first = comparison.highlighted.min() else { return }
                    DispatchQueue.main.async { proxy.scrollTo(first, anchor: .top) }
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
            // Під кнопками заголовка — щоб колонки стояли точно під своїми назвами.
            Color.clear.frame(width: 44 * scale.factor, height: 1)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(highlighted ? Color(theme.selection) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("compare-row-\(row.primary.verse)")
        .accessibilityValue(highlighted ? "виділено" : "")
    }

    /// Порожня клітинка — вірш злито з попереднім або відповідника немає.
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

/// Вікно вибору перекладів для «Порівняти»: чекбокси, вибір запам'ятовується в налаштуваннях.
/// Переклад на екрані завжди перша колонка, тож його в списку немає.
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
