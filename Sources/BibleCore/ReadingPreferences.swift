import Foundation
import Observation

/// Масштаб інтерфейсу відносно системного розміру шрифту macOS (FR-16).
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

    /// `base` — системний розмір шрифту (`NSFont.systemFontSize`).
    public func fontSize(base: Double) -> Double { (base * factor * 100).rounded() / 100 }
}

/// Розміри шрифтів і масштаб інтерфейсу (FR-15, FR-16). Сеттери обрізають значення до меж.
public struct ReadingPreferences: Equatable, Codable, Sendable {
    public static let defaultVerseFontSize = 15.0
    public static let defaultBookListFontSize = 13.0
    public static let verseFontRange = 11.0...32.0
    public static let bookListFontRange = 11.0...24.0

    public var verseFontSize: Double {
        didSet { verseFontSize = verseFontSize.clamped(to: Self.verseFontRange) }
    }
    public var bookListFontSize: Double {
        didSet { bookListFontSize = bookListFontSize.clamped(to: Self.bookListFontRange) }
    }
    public var interfaceScale: InterfaceScale

    public init(
        verseFontSize: Double = defaultVerseFontSize,
        bookListFontSize: Double = defaultBookListFontSize,
        interfaceScale: InterfaceScale = .standard
    ) {
        self.verseFontSize = verseFontSize.clamped(to: Self.verseFontRange)
        self.bookListFontSize = bookListFontSize.clamped(to: Self.bookListFontRange)
        self.interfaceScale = interfaceScale
    }

    /// Відсутнє чи невідоме поле бере стандартне значення, решта збережених лишається.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            verseFontSize: (try? c.decodeIfPresent(Double.self, forKey: .verseFontSize)) ?? Self.defaultVerseFontSize,
            bookListFontSize: (try? c.decodeIfPresent(Double.self, forKey: .bookListFontSize)) ?? Self.defaultBookListFontSize,
            interfaceScale: (try? c.decodeIfPresent(InterfaceScale.self, forKey: .interfaceScale)) ?? .standard)
    }

    public var canIncreaseVerseFont: Bool { verseFontSize < Self.verseFontRange.upperBound }
    public var canDecreaseVerseFont: Bool { verseFontSize > Self.verseFontRange.lowerBound }
    public var isVerseFontDefault: Bool { verseFontSize == Self.defaultVerseFontSize }

    public mutating func increaseVerseFont() { verseFontSize += 1 }
    public mutating func decreaseVerseFont() { verseFontSize -= 1 }
    public mutating func resetVerseFont() { verseFontSize = Self.defaultVerseFontSize }
}

private extension Double {
    /// Цілі pt у межах: крок завжди 1, тож порівняння зі стандартом точне.
    func clamped(to range: ClosedRange<Double>) -> Double { Swift.min(Swift.max(rounded(), range.lowerBound), range.upperBound) }
}

/// Сховище ключ–значення; у додатку це `UserDefaults`, у тестах — словник.
public protocol KeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String)
    func removeObject(forKey key: String)
}

extension UserDefaults: KeyValueStore {
    public func set(_ data: Data, forKey key: String) { set(data as Any, forKey: key) }
}

/// Тримає `ReadingPreferences` і зберігає їх при кожній зміні. Немає даних або вони пошкоджені → стандартні значення.
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
        // Кодування трьох простих полів не може впасти.
        storage.set(try! JSONEncoder().encode(preferences), forKey: Self.key)
    }
}
