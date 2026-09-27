import BibleCore
import SwiftUI

/// Напівпрозора кнопка копіювання над першим виділеним віршем (FR-17).
/// Широка кнопка з написом у правому полі рядка; текст вірша під неї не заходить.
struct CopyButton: View {
    /// Ширина кнопки за масштабом інтерфейсу; `ChapterView` лишає рядку з кнопкою праве поле такої ширини.
    static func width(for scale: InterfaceScale) -> CGFloat { 124 * scale.factor }

    let action: () -> Void
    @State private var copies = 0
    @State private var showCopied = false
    @State private var isHovered = false
    @Environment(\.theme) private var theme
    @Environment(\.interfaceScale) private var scale

    var body: some View {
        Button {
            action()
            showCopied = true
            copies += 1
        } label: {
            // Фіксована ширина: «Копіювати» і «Скопійовано» займають те саме місце в правому полі рядка.
            Label(showCopied ? "Скопійовано" : "Копіювати", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                .labelStyle(.titleAndIcon)
                .frame(width: CopyButton.width(for: scale) - 12)
                .font(.system(size: scale.systemFontSize))
                .foregroundStyle(Color(theme.accent))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                // Напівпрозора лише підкладка: іконка лишається контрастною (FR-32).
                .background(
                    Color(theme.copyButton).opacity(isHovered || showCopied ? 1 : 0.6),
                    in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.borderless)
        .onHover { isHovered = $0 }
        .help("Копіювати цитату")
        .accessibilityLabel(showCopied ? "Скопійовано" : "Копіювати цитату")
        .accessibilityIdentifier("copy-button")
        // Повторний клік перезапускає відлік; зникнення view скасовує його.
        .task(id: copies) {
            guard copies > 0 else { return }
            try? await Task.sleep(for: CopyButtonModel.feedbackDuration)
            if !Task.isCancelled { showCopied = false }
        }
    }
}
