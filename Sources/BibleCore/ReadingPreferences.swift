import Foundation
import Observation

/// Interface scale relative to the macOS system font size (FR-16).
public enum InterfaceScale: String, CaseIterable, Codable, Sendable {
    case small, standard, large, extraLarge

    public var factor: Double {
        switch self {
        case .small: 0.85
        case .standard: 1.0
        case .large: 1.2
        case .extraLarge: 1.4
        }
    }

    public var title: String {
        switch self {
        case .small: "Малий"
        case .standard: "Стандарт"
        case .large: "Великий"
        case .extraLarge: "Дуже великий"
        }
    }

    /// `base` is the system font size (`NSFont.systemFontSize`).
    public func fontSize(base: Double) -> Double { (base * factor * 100).rounded() / 100 }
}

/// Font sizes and interface scale (FR-15, FR-16). Setters clamp values to the limits.
public struct ReadingPreferences: Equatable, Codable, Sendable {
    public static let defaultVerseFontSize = 15.0
    public static let defaultBookListFontSize = 13.0
    public static let verseFontRange = 11.0...32.0
    public static let bookListFontRange = 11.0...32.0

    /// The text column without a parallel translation: ~75 characters per line (an average character ≈ 0.5 em) plus the verse number.
    public static let readingColumnEms = 40.0

    public static func readingColumnWidth(fontSize: Double) -> Double { fontSize * readingColumnEms }

    public var verseFontSize: Double {
        didSet { verseFontSize = verseFontSize.clamped(to: Self.verseFontRange) }
    }
    public var bookListFontSize: Double {
        didSet { bookListFontSize = bookListFontSize.clamped(to: Self.bookListFontRange) }
    }
    public var interfaceScale: InterfaceScale
    public var theme: ThemeChoice
    /// Translations chosen for "Compare" (FR-36), in column order.
    public var comparePanels: ComparePanels
    /// The second translation alongside (FR-26); `nil` means off.
    public var parallelTranslation: Translation?

    public init(
        verseFontSize: Double = defaultVerseFontSize,
        bookListFontSize: Double = defaultBookListFontSize,
        interfaceScale: InterfaceScale = .standard,
        theme: ThemeChoice = .system,
        comparePanels: ComparePanels = ComparePanels(),
        parallelTranslation: Translation? = nil
    ) {
        self.verseFontSize = verseFontSize.clamped(to: Self.verseFontRange)
        self.bookListFontSize = bookListFontSize.clamped(to: Self.bookListFontRange)
        self.interfaceScale = interfaceScale
        self.theme = theme
        self.comparePanels = comparePanels
        self.parallelTranslation = parallelTranslation
    }

    /// A missing or unknown field takes the default value, the rest of the saved ones stay.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            verseFontSize: (try? c.decodeIfPresent(Double.self, forKey: .verseFontSize)) ?? Self.defaultVerseFontSize,
            bookListFontSize: (try? c.decodeIfPresent(Double.self, forKey: .bookListFontSize)) ?? Self.defaultBookListFontSize,
            interfaceScale: (try? c.decodeIfPresent(InterfaceScale.self, forKey: .interfaceScale)) ?? .standard,
            theme: (try? c.decodeIfPresent(ThemeChoice.self, forKey: .theme)) ?? .system,
            comparePanels: (try? c.decodeIfPresent(ComparePanels.self, forKey: .comparePanels)) ?? ComparePanels(),
            parallelTranslation: try? c.decodeIfPresent(Translation.self, forKey: .parallelTranslation))
    }

    // ⌘+ / ⌘− / ⌘0 change verse text and the book list together; each is clamped to its own limits.
    public var canIncreaseFonts: Bool {
        verseFontSize < Self.verseFontRange.upperBound || bookListFontSize < Self.bookListFontRange.upperBound
    }
    public var canDecreaseFonts: Bool {
        verseFontSize > Self.verseFontRange.lowerBound || bookListFontSize > Self.bookListFontRange.lowerBound
    }
    public var areFontsDefault: Bool {
        verseFontSize == Self.defaultVerseFontSize && bookListFontSize == Self.defaultBookListFontSize
    }

    public mutating func increaseFonts() {
        verseFontSize += 1
        bookListFontSize += 1
    }

    public mutating func decreaseFonts() {
        verseFontSize -= 1
        bookListFontSize -= 1
    }

    public mutating func resetFonts() {
        verseFontSize = Self.defaultVerseFontSize
        bookListFontSize = Self.defaultBookListFontSize
    }
}

private extension Double {
    /// Whole pt within the limits: the step is always 1, so comparing with the default is exact.
    func clamped(to range: ClosedRange<Double>) -> Double { Swift.min(Swift.max(rounded(), range.lowerBound), range.upperBound) }
}

/// A key–value store; `UserDefaults` in the app, a dictionary in tests.
public protocol KeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String)
    func removeObject(forKey key: String)
}

extension UserDefaults: KeyValueStore {
    public func set(_ data: Data, forKey key: String) { set(data as Any, forKey: key) }
}

/// Holds `ReadingPreferences` and saves them on every change. No data or corrupted data → default values.
@MainActor @Observable
public final class PreferencesStore {
    public static let key = "readingPreferences"

    public var preferences: ReadingPreferences {
        didSet { save() }
    }

    @ObservationIgnored private let storage: KeyValueStore

    public init(storage: KeyValueStore) {
        self.storage = storage
        preferences = storage.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(ReadingPreferences.self, from: $0) }
            ?? ReadingPreferences()
    }

    public func reset() {
        storage.removeObject(forKey: Self.key)
        preferences = ReadingPreferences()
    }

    private func save() {
        // Encoding three simple fields cannot fail.
        storage.set(try! JSONEncoder().encode(preferences), forKey: Self.key)
    }
}
