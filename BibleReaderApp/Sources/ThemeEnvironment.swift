import AppKit
import BibleCore
import CoreText
import OSLog
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
        case .ebGaramond:
            // Garamond дрібніший на тому ж кеглі; якщо шрифт не зареєструвався — системний serif.
            ThemeFonts.garamondAvailable
                ? .custom(ThemeFonts.garamond, size: size * 1.12)
                : .system(size: size, design: .serif)
        }
    }
}

enum ThemeFonts {
    /// PostScript-ім'я вшитого EB Garamond (OFL).
    static let garamond = "EBGaramond-Regular"
    private static let log = Logger(subsystem: "dev.taraniuk.BibleReader", category: "fonts")

    static var garamondAvailable: Bool { NSFont(name: garamond, size: 12) != nil }

    /// Реєструє вшиті шрифти (`Resources/Fonts`) для процесу додатка; помилки йдуть у журнал.
    static func register() {
        guard let folder = Bundle.main.url(forResource: "Fonts", withExtension: nil),
              let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        else {
            log.error("Fonts folder missing from the bundle")
            return
        }
        for url in files where url.pathExtension == "ttf" {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                log.error("Cannot register \(url.lastPathComponent): \(String(describing: error?.takeRetainedValue()))")
            }
        }
    }
}

/// Застосовує тему до вікна: токени в середовище, колір тексту й акценту, світла/темна схема AppKit.
/// Схему задаємо через `NSApp.appearance`: `preferredColorScheme(nil)` не повертає вікно до системної.
struct ThemedScene: ViewModifier {
    let preferences: PreferencesStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var choice: ThemeChoice { preferences.preferences.theme }
    private var theme: ThemeTokens {
        Theme.tokens(
            // Для «Як у системі» appearance скинуто, тож `scheme` — схема macOS.
            for: choice.resolve(systemIsDark: scheme == .dark),
            reduceTransparency: reduceTransparency,
            increaseContrast: contrast == .increased)
    }

    func body(content: Content) -> some View {
        content
            .environment(\.theme, theme)
            .environment(\.interfaceScale, preferences.preferences.interfaceScale)
            .foregroundStyle(Color(theme.text))
            .tint(Color(theme.accent))
            .onChange(of: choice, initial: true) { _, choice in
                switch choice {
                case .system: NSApp.appearance = nil
                case .theme(let id):
                    let dark = Theme.tokens(for: id).colorScheme == .dark
                    NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                }
            }
    }
}

struct ThemePicker: View {
    @Bindable var preferences: PreferencesStore

    var body: some View {
        Picker("Тема", selection: $preferences.preferences.theme) {
            ForEach(ThemeChoice.allCases, id: \.self) { Text($0.title).tag($0) }
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
            // Колір панелі з непрозорістю хрому поверх розмиття: контраст перевірено на чорному і білому тлі.
            let tint = Color(color).opacity(theme.chromeOpacity)
            if #available(macOS 26, *) {
                content.scrollContentBackground(.hidden)
                    .background(tint.ignoresSafeArea())
                    .glassEffect(.regular, in: .rect)
            } else {
                content.scrollContentBackground(.hidden)
                    .background(tint.ignoresSafeArea())
                    .background(.ultraThinMaterial)
            }
        } else {
            content.scrollContentBackground(.hidden)
                .background(Color(color).ignoresSafeArea())
        }
    }
}

/// Пергамент, намальований кодом: волокна, плями, потемніння по краях. Плитка 512×512 рахується один раз
/// з фіксованим seed і повторюється, тож візерунок не «стрибає» при зміні розміру. Непрозорість задає тема (~7 %).
struct ParchmentTexture: View {
    private static let tile: CGFloat = 512
    private static let ink = Color(red: 0.35, green: 0.24, blue: 0.12)

    private struct Fiber { let path: Path; let opacity: Double }
    private struct Stain { let rect: CGRect; let radius: CGFloat }

    private static let fibers: [Fiber] = {
        var rng = SeededGenerator(seed: 0x5EED_B1B1E)
        return (0..<180).map { _ in
            let x = Double.random(in: 0...tile, using: &rng), y = Double.random(in: 0...tile, using: &rng)
            let length = Double.random(in: 6...22, using: &rng), angle = Double.random(in: -0.4...0.4, using: &rng)
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length))
            return Fiber(path: path, opacity: Double.random(in: 0.15...0.45, using: &rng))
        }
    }()

    private static let stains: [Stain] = {
        var rng = SeededGenerator(seed: 0x57A1_4E)
        return (0..<3).map { _ in
            let r = Double.random(in: 30...110, using: &rng)
            let rect = CGRect(
                x: Double.random(in: 0...tile, using: &rng) - r,
                y: Double.random(in: 0...tile, using: &rng) - r, width: r * 2, height: r * 2)
            return Stain(rect: rect, radius: r)
        }
    }()

    var body: some View {
        Canvas { context, size in
            for x in stride(from: 0, to: size.width, by: Self.tile) {
                for y in stride(from: 0, to: size.height, by: Self.tile) {
                    var tile = context
                    tile.translateBy(x: x, y: y)
                    for fiber in Self.fibers {
                        tile.stroke(fiber.path, with: .color(Self.ink.opacity(fiber.opacity)), lineWidth: 0.5)
                    }
                    for stain in Self.stains {
                        tile.fill(Path(ellipseIn: stain.rect), with: .radialGradient(
                            Gradient(colors: [Self.ink.opacity(0.25), .clear]),
                            center: CGPoint(x: stain.rect.midX, y: stain.rect.midY), startRadius: 0, endRadius: stain.radius))
                    }
                }
            }
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .radialGradient(
                Gradient(colors: [.clear, Self.ink.opacity(0.9)]),
                center: CGPoint(x: rect.midX, y: rect.midY),
                startRadius: min(size.width, size.height) * 0.35,
                endRadius: max(size.width, size.height) * 0.75))
        }
        .drawingGroup()
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

/// Тулбар у кольорі панелі теми (для Скла — напівпрозорому).
struct ToolbarTheme: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .toolbarBackground(Color(theme.sidebar).opacity(theme.chromeOpacity), for: .windowToolbar)
            .toolbarBackground(.visible, for: .windowToolbar)
    }
}
