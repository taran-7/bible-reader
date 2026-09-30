import BibleCore
import SwiftUI

/// A button on the selection: an icon with a label, the same width for "Illustrations", "Compare", "Copy",
/// a semi-transparent backing, the verse text does not run under it (FR-17, FR-33, FR-36).
struct SelectionButton: View {
    /// Each button's width by the interface scale; `compact` means icon only (a narrow text column).
    static func width(for scale: InterfaceScale, compact: Bool = false) -> CGFloat { (compact ? 32 : 124) * scale.factor }
    static let spacing: CGFloat = 4

    /// The row's right margin for `count` buttons (three; the fourth is "To draft" when drafts are open).
    static func rowWidth(for scale: InterfaceScale, compact: Bool = false, count: Int = 3) -> CGFloat {
        CGFloat(count) * width(for: scale, compact: compact) + CGFloat(count - 1) * spacing + 12
    }

    /// Labels only when the verse text keeps at least 360 pt; otherwise the verse shrinks into a narrow tall
    /// column, and the buttons above the first selected verse go past the edge when scrolling.
    static func isCompact(listWidth: CGFloat, scale: InterfaceScale, count: Int = 3) -> Bool {
        listWidth - rowWidth(for: scale, count: count) < 360 * scale.factor
    }

    let title: String
    let systemImage: String
    let help: String
    let identifier: String
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.theme) private var theme
    @Environment(\.interfaceScale) private var scale
    @Environment(\.compactSelectionButtons) private var compact

    var body: some View {
        Button(action: action) {
            Group {
                if compact {
                    Label(title, systemImage: systemImage).labelStyle(.iconOnly)
                } else {
                    Label(title, systemImage: systemImage).labelStyle(.titleAndIcon)
                }
            }
                .lineLimit(1)
                .frame(width: SelectionButton.width(for: scale, compact: compact) - 12)
                .font(.system(size: scale.systemFontSize))
                .foregroundStyle(Color(theme.accent))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                // Only the backing is semi-transparent: the icon and text stay high-contrast (FR-32).
                .background(Color(theme.copyButton).opacity(isHovered ? 1 : 0.6), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.borderless)
        .onHover { isHovered = $0 }
        .help(help)
        .accessibilityLabel(help)
        .accessibilityIdentifier(identifier)
    }
}

/// "Copy" → "Copied" for ~1.5 s in the same place (FR-17).
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
        // A repeated click restarts the countdown; the view disappearing cancels it.
        .task(id: copies) {
            guard copies > 0 else { return }
            try? await Task.sleep(for: CopyButtonModel.feedbackDuration)
            if !Task.isCancelled { showCopied = false }
        }
    }
}

/// "Compare" (FR-36).
struct CompareButton: View {
    let action: () -> Void

    var body: some View {
        SelectionButton(title: "Порівняти", systemImage: "rectangle.split.3x1", help: "Порівняти в перекладах",
                        identifier: "compare-button", action: action)
    }
}

extension EnvironmentValues {
    /// Selection buttons with icons only (a narrow text column); the tooltip stays.
    @Entry var compactSelectionButtons = false
}
