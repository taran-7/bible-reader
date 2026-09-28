import BibleCore
import SwiftUI

/// Кнопка на виділенні: іконка з написом, однакова ширина для «Ілюстрації», «Порівняти», «Копіювати»,
/// напівпрозора підкладка, текст вірша під неї не заходить (FR-17, FR-33, FR-36).
struct SelectionButton: View {
    /// Ширина кожної кнопки за масштабом інтерфейсу; `ChapterView` лишає рядку з кнопками праве поле під три.
    static func width(for scale: InterfaceScale) -> CGFloat { 124 * scale.factor }
    static let spacing: CGFloat = 4

    /// Праве поле рядка під три кнопки.
    static func rowWidth(for scale: InterfaceScale) -> CGFloat { 3 * width(for: scale) + 2 * spacing + 12 }

    let title: String
    let systemImage: String
    let help: String
    let identifier: String
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.theme) private var theme
    @Environment(\.interfaceScale) private var scale

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .frame(width: SelectionButton.width(for: scale) - 12)
                .font(.system(size: scale.systemFontSize))
                .foregroundStyle(Color(theme.accent))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                // Напівпрозора лише підкладка: іконка й текст лишаються контрастними (FR-32).
                .background(Color(theme.copyButton).opacity(isHovered ? 1 : 0.6), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.borderless)
        .onHover { isHovered = $0 }
        .help(help)
        .accessibilityLabel(help)
        .accessibilityIdentifier(identifier)
    }
}

/// «Копіювати» → на ~1,5 с «Скопійовано» на тому самому місці (FR-17).
struct CopyButton: View {
    let action: () -> Void
    @State private var copies = 0
    @State private var showCopied = false

    var body: some View {
        SelectionButton(title: showCopied ? "Скопійовано" : "Копіювати", systemImage: showCopied ? "checkmark" : "doc.on.doc",
                        help: showCopied ? "Скопійовано" : "Копіювати цитату", identifier: "copy-button") {
            action()
            showCopied = true
            copies += 1
        }
        // Повторний клік перезапускає відлік; зникнення view скасовує його.
        .task(id: copies) {
            guard copies > 0 else { return }
            try? await Task.sleep(for: CopyButtonModel.feedbackDuration)
            if !Task.isCancelled { showCopied = false }
        }
    }
}

/// «Порівняти» (FR-36).
struct CompareButton: View {
    let action: () -> Void

    var body: some View {
        SelectionButton(title: "Порівняти", systemImage: "rectangle.split.3x1", help: "Порівняти в перекладах",
                        identifier: "compare-button", action: action)
    }
}
