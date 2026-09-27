import BibleCore
import CoreText
import SwiftUI

extension Color {
    init(_ color: ThemeColor) { self.init(.sRGB, red: color.red, green: color.green, blue: color.blue) }
}

extension EnvironmentValues {
    @Entry var theme: ThemeTokens = Theme.tokens(for: .light)
}

extension ThemeTokens {
    func verseFont(size: Double) -> Font {
        switch font {
        case .newYork: .system(size: size, design: .serif)
        case .sfPro: .system(size: size)
        case .ebGaramond: .custom(ThemeFonts.garamond, size: size * 1.12) // Garamond дрібніший на тому ж кеглі
        }
    }

    var preferredColorScheme: ColorScheme { colorScheme == .dark ? .dark : .light }
}

enum ThemeFonts {
    static let garamond = "EB Garamond"

    /// Реєструє вшиті шрифти (`Resources/Fonts`, OFL) для процесу додатка.
    static func register() {
        guard let folder = Bundle.main.url(forResource: "Fonts", withExtension: nil),
              let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        else { return }
        for url in files where url.pathExtension == "ttf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

/// Фон під віршами: підкладка теми, для Скла напівпрозора, для Манускрипту з текстурою.
struct ThemeBackground: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Color(theme.background).opacity(theme.plateOpacity)
            if theme.textureOpacity > 0 {
                ParchmentTexture().opacity(theme.textureOpacity)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Бічна панель і інший «хром»: Скло — розмите скло, інші теми — колір панелі.
struct ChromeBackground: ViewModifier {
    let color: ThemeColor
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        if theme.usesGlass {
            if #available(macOS 26, *) {
                content.scrollContentBackground(.hidden)
                    .background(Color(color).opacity(0.35))
                    .glassEffect(.regular, in: .rect)
            } else {
                content.scrollContentBackground(.hidden)
                    .background(.ultraThinMaterial)
            }
        } else {
            content.scrollContentBackground(.hidden)
                .background(Color(color).ignoresSafeArea())
        }
    }
}

/// Пергамент, намальований кодом: волокна, плями, потемніння по краях. Детермінований seed —
/// та сама картинка при кожному рендері. Непрозорість задає тема (~7 %).
struct ParchmentTexture: View {
    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            var rng = SeededGenerator(seed: 0x5EED_B1B1E)
            let ink = Color(red: 0.35, green: 0.24, blue: 0.12)
            // Волокна: короткі тонкі штрихи.
            for _ in 0..<Int(size.width * size.height / 900) {
                let x = Double.random(in: 0...size.width, using: &rng)
                let y = Double.random(in: 0...size.height, using: &rng)
                let length = Double.random(in: 6...22, using: &rng)
                let angle = Double.random(in: -0.4...0.4, using: &rng)
                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length))
                context.stroke(path, with: .color(ink.opacity(Double.random(in: 0.15...0.45, using: &rng))), lineWidth: 0.5)
            }
            // Плями.
            for _ in 0..<12 {
                let r = Double.random(in: 30...120, using: &rng)
                let rect = CGRect(
                    x: Double.random(in: 0...size.width, using: &rng) - r,
                    y: Double.random(in: 0...size.height, using: &rng) - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .radialGradient(
                    Gradient(colors: [ink.opacity(0.25), .clear]),
                    center: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0, endRadius: r))
            }
            // Потемніння по краях.
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .radialGradient(
                Gradient(colors: [.clear, ink.opacity(0.9)]),
                center: CGPoint(x: rect.midX, y: rect.midY),
                startRadius: min(size.width, size.height) * 0.35,
                endRadius: max(size.width, size.height) * 0.75))
        }
    }
}

/// Простий детермінований генератор (SplitMix64) для текстури.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Тулбар у кольорі панелі теми; для Скла лишається системне скло.
struct ToolbarTheme: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        if theme.usesGlass {
            content
        } else if #available(macOS 15, *) {
            content
                .toolbarBackground(Color(theme.sidebar), for: .windowToolbar)
                .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        } else {
            content.toolbarBackground(Color(theme.sidebar), for: .windowToolbar)
        }
    }
}
