import BibleCore
import SwiftUI

/// Напівпрозора кнопка копіювання над першим виділеним віршем (FR-17).
/// У спокої це лише іконка в правому полі рядка; напис «Скопійовано» на 1,5 с може лягти на край тексту.
struct CopyButton: View {
    let action: () -> Void
    @State private var copies = 0
    @State private var showCopied = false
    @State private var isHovered = false
    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            action()
            showCopied = true
            copies += 1
        } label: {
            Group {
                if showCopied {
                    Label("Скопійовано", systemImage: "checkmark").labelStyle(.titleAndIcon)
                } else {
                    Image(systemName: "doc.on.doc")
                }
            }
            .font(.callout)
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
