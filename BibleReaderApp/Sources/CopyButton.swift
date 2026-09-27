import BibleCore
import SwiftUI

/// Напівпрозора кнопка копіювання над першим виділеним віршем (FR-17).
struct CopyButton: View {
    let action: () -> Void
    @State private var model = CopyButtonModel()
    @State private var isHovered = false
    /// Змінюється, коли минає час «Скопійовано», щоб view перечитав `model`.
    @State private var tick = 0

    var body: some View {
        let copied = model.isShowingCopied(at: .now)
        Button {
            action()
            model.markCopied(at: .now)
            tick += 1
            Task {
                try? await Task.sleep(for: .seconds(CopyButtonModel.feedbackDuration))
                tick += 1
            }
        } label: {
            Group {
                if copied {
                    Label("Скопійовано", systemImage: "checkmark").labelStyle(.titleAndIcon)
                } else {
                    Image(systemName: "doc.on.doc")
                }
            }
            .font(.callout)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            .id(tick)
        }
        .buttonStyle(.borderless)
        .opacity(isHovered || copied ? 1 : 0.6)
        .onHover { isHovered = $0 }
        .help("Копіювати цитату")
        .accessibilityLabel(copied ? "Скопійовано" : "Копіювати цитату")
        .accessibilityIdentifier("copy-button")
    }
}
