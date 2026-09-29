import Foundation

/// Колір sRGB з компонентами 0…1 і контрастом за WCAG 2.x (FR-32).
public struct ThemeColor: Equatable, Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }

    public var hex: UInt32 {
        func byte(_ v: Double) -> UInt32 { UInt32((min(max(v, 0), 1) * 255).rounded()) }
        return byte(red) << 16 | byte(green) << 8 | byte(blue)
    }

    /// Відносна яскравість WCAG.
    public var luminance: Double {
        func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    public func contrast(with other: ThemeColor) -> Double {
        let (a, b) = (luminance, other.luminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// Цей колір з непрозорістю `opacity`, накладений на `background`.
    public func composited(over background: ThemeColor, opacity: Double) -> ThemeColor {
        func mix(_ top: Double, _ bottom: Double) -> Double { top * opacity + bottom * (1 - opacity) }
        return ThemeColor(red: mix(red, background.red), green: mix(green, background.green), blue: mix(blue, background.blue))
    }

    /// Найменше зміщення до чорного чи білого (що далі від фонів), яке дає потрібний контраст на кожному з фонів.
    /// На крайньому кроці колір стає чистим полюсом; якщо й це не досягає цілі, тест контрасту це покаже.
    func strengthened(toContrast target: Double, against backgrounds: [ThemeColor]) -> ThemeColor {
        let light = backgrounds.map(\.luminance).reduce(0, +) / Double(backgrounds.count) > 0.18
        let pole = ThemeColor(hex: light ? 0x000000 : 0xFFFFFF)
        for step in stride(from: 0.0, through: 1.0, by: 0.05) {
            let color = pole.composited(over: self, opacity: step)
            if backgrounds.allSatisfy({ color.contrast(with: $0) >= target }) { return color }
        }
        return pole
    }
}

public enum ThemeID: String, CaseIterable, Codable, Sendable {
    case light, dark, glass, pastel, manuscript

    public var title: String {
        switch self {
        case .light: "Світла"
        case .dark: "Темна"
        case .glass: "Скло"
        case .pastel: "Пастельна"
        case .manuscript: "Манускрипт"
        }
    }
}

/// Вибір користувача: «Як у системі» або конкретна тема (FR-31).
public enum ThemeChoice: Hashable, Sendable, CaseIterable, Codable {
    case system
    case theme(ThemeID)

    public static var allCases: [ThemeChoice] { [.system] + ThemeID.allCases.map(ThemeChoice.theme) }

    public var title: String {
        switch self {
        case .system: "Як у системі"
        case .theme(let id): id.title
        }
    }

    public func resolve(systemIsDark: Bool) -> ThemeID {
        switch self {
        case .system: systemIsDark ? .dark : .light
        case .theme(let id): id
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ThemeID(rawValue: raw).map(ThemeChoice.theme) ?? .system
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .system: try container.encode("system")
        case .theme(let id): try container.encode(id.rawValue)
        }
    }
}

public enum ThemeFont: Sendable, Equatable {
    /// Системний serif macOS.
    case newYork
    case sfPro
    /// Вшитий у додаток, OFL.
    case ebGaramond
}

public enum ThemeColorScheme: Sendable, Equatable { case light, dark }

/// Набір токенів теми; SwiftUI лише застосовує їх (PRD 6.18).
public struct ThemeTokens: Sendable, Equatable {
    public var background: ThemeColor
    public var sidebar: ThemeColor
    public var results: ThemeColor
    public var text: ThemeColor
    public var secondaryText: ThemeColor
    public var accent: ThemeColor
    public var verseNumber: ThemeColor
    public var searchHighlight: ThemeColor
    public var selection: ThemeColor
    /// Фон вибраної книги в бічній панелі.
    public var sidebarSelection: ThemeColor
    public var copyButton: ThemeColor
    public var font: ThemeFont
    public var colorScheme: ThemeColorScheme
    /// Непрозорість підкладки під віршами (Скло: 0,92 поверх розмитого тла).
    public var plateOpacity: Double = 1
    /// Непрозорість кольору панелі поверх матеріалу/скла в бічній панелі й тулбарі (Скло: 0,92).
    public var chromeOpacity: Double = 1
    public var usesGlass = false
    public var textureOpacity: Double = 0
    /// Додатковий інтервал між рядками в частках кегля: 0,5 → висота рядка 1,5.
    public var lineSpacing: Double = 0.5

    /// Фони, на яких реально опиняється текст віршів: для напівпрозорої підкладки — на чорному і на білому тлі.
    public var effectiveBackgrounds: [ThemeColor] { Self.onAnyBackdrop(background, opacity: plateOpacity) }

    /// Те саме для бічної панелі й тулбара.
    public var effectiveSidebars: [ThemeColor] { Self.onAnyBackdrop(sidebar, opacity: chromeOpacity) }

    private static func onAnyBackdrop(_ color: ThemeColor, opacity: Double) -> [ThemeColor] {
        guard opacity < 1 else { return [color] }
        return [ThemeColor(hex: 0x000000), ThemeColor(hex: 0xFFFFFF)].map { color.composited(over: $0, opacity: opacity) }
    }
}

public enum Theme {
    public static func tokens(for id: ThemeID, reduceTransparency: Bool = false, increaseContrast: Bool = false) -> ThemeTokens {
        var t = base(id)
        if reduceTransparency {
            t.plateOpacity = 1
            t.chromeOpacity = 1
            t.usesGlass = false
            t.textureOpacity = 0
        }
        if increaseContrast {
            let dark = t.colorScheme == .dark
            t.text = ThemeColor(hex: dark ? 0xFFFFFF : 0x000000)
            t.secondaryText = t.text
            t.accent = t.accent.strengthened(toContrast: 7, against: t.effectiveBackgrounds)
            t.verseNumber = t.verseNumber.strengthened(toContrast: 7, against: t.effectiveBackgrounds)
        }
        return t
    }

    private static func c(_ hex: UInt32) -> ThemeColor { ThemeColor(hex: hex) }

    private static func base(_ id: ThemeID) -> ThemeTokens {
        switch id {
        case .light:
            ThemeTokens(
                background: c(0xFFFFFF), sidebar: c(0xF5F5F7), results: c(0xFFFFFF),
                text: c(0x1C1C1E), secondaryText: c(0x6E6E73), accent: c(0x0A66C2), verseNumber: c(0x5F5F66),
                searchHighlight: c(0xFFE58F), selection: c(0xDCE9F9), sidebarSelection: c(0xE3E3E8), copyButton: c(0xF2F2F7),
                font: .newYork, colorScheme: .light)
        case .dark:
            ThemeTokens(
                background: c(0x121214), sidebar: c(0x1C1C1F), results: c(0x121214),
                text: c(0xE8E6E3), secondaryText: c(0x9A9AA0), accent: c(0x6CB4FF), verseNumber: c(0xAEAEB4),
                searchHighlight: c(0x5C4A12), selection: c(0x1F3A5C), sidebarSelection: c(0x2E2E33), copyButton: c(0x2A2A2E),
                font: .newYork, colorScheme: .dark)
        case .glass:
            ThemeTokens(
                background: c(0xF2F4F8), sidebar: c(0xEEF1F6), results: c(0xF2F4F8),
                text: c(0x101218), secondaryText: c(0x5A5F6B), accent: c(0x1F57C8), verseNumber: c(0x5A5F6B),
                searchHighlight: c(0xFFE58F), selection: c(0xD6E2F7), sidebarSelection: c(0xDDE3EE), copyButton: c(0xFFFFFF),
                font: .sfPro, colorScheme: .light, plateOpacity: 0.92, chromeOpacity: 0.92, usesGlass: true)
        case .pastel:
            // Палітра coolors.co/512d38-b27092-f4bfdb-ffe9f3; акценти — темніші відтінки B27092 заради контрасту.
            ThemeTokens(
                background: c(0xFFE9F3), sidebar: c(0xF4BFDB), results: c(0xFFF5F9),
                text: c(0x512D38), secondaryText: c(0x7A3E5E), accent: c(0x8C4A6E), verseNumber: c(0x7A3E5E),
                searchHighlight: c(0xD6EDDD), selection: c(0xF4BFDB), sidebarSelection: c(0xFFE9F3), copyButton: c(0xFFF5F9),
                font: .newYork, colorScheme: .light)
        case .manuscript:
            ThemeTokens(
                background: c(0xEFE4CC), sidebar: c(0xE8DCC0), results: c(0xEFE4CC),
                text: c(0x3B2A1A), secondaryText: c(0x6B5238), accent: c(0x8B2E1F), verseNumber: c(0x8B2E1F),
                searchHighlight: c(0xE6C77A), selection: c(0xDCCBA4), sidebarSelection: c(0xDCCBA4), copyButton: c(0xF5ECD8),
                font: .ebGaramond, colorScheme: .light, textureOpacity: 0.07)
        }
    }
}

/// Вигляд поля пошуку в тулбарі: його малює AppKit, тож SwiftUI-шар застосовує ці значення
/// до `NSSearchField` напряму (tech debt #15, #18).
public struct SearchFieldStyle: Equatable, Sendable {
    public let fontSize: Double
    public let text: ThemeColor
    public let background: ThemeColor
    public let colorScheme: ThemeColorScheme

    /// `fontSize` — системний кегль, уже помножений на масштаб інтерфейсу.
    public init(theme: ThemeTokens, fontSize: Double) {
        self.fontSize = fontSize
        text = theme.text
        // Поле лежить на тулбарі кольору бічної панелі; фон — як у результатів пошуку, щоб контрастувати з ним.
        background = theme.results
        colorScheme = theme.colorScheme
    }
}
