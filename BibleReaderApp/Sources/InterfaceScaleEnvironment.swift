import AppKit
import BibleCore
import SwiftUI

extension InterfaceScale {
    /// The base interface text size: the macOS system font size × scale (FR-16).
    var systemFontSize: CGFloat { fontSize(base: NSFont.systemFontSize) }
    var controlSize: ControlSize {
        switch self {
        case .small: .small
        case .standard: .regular
        case .large: .large
        case .extraLarge: .extraLarge
        }
    }
}

extension EnvironmentValues {
    @Entry var interfaceScale: InterfaceScale = .standard
}

/// A message screen with explicit fonts: `ContentUnavailableView` does not take the font from the environment.
struct MessageView: View {
    let title: String
    let systemImage: String
    let lines: [String]
    @Environment(\.interfaceScale) private var scale
    @Environment(\.theme) private var theme

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
                .font(.system(size: scale.systemFontSize * 1.5, weight: .semibold))
                .foregroundStyle(Color(theme.text))
        } description: {
            ForEach(lines, id: \.self) {
                Text($0).font(.system(size: scale.systemFontSize)).foregroundStyle(Color(theme.secondaryText))
            }
        }
    }
}
