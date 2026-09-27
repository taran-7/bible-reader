/// Мова перекладу: визначає назви книг, посилання й цитати.
public enum Language: String, Sendable {
    case english, russian, ukrainian, czech

    public var title: String {
        switch self {
        case .english: "English"
        case .russian: "русский"
        case .ukrainian: "українська"
        case .czech: "čeština"
        }
    }
}

/// Переклад, який показується на екрані.
/// Порядок `case` — порядок у меню і в ⌘⌥1…4 (рішення власника 2026-09-27).
public enum Translation: String, CaseIterable, Sendable, Codable {
    case kjv
    case bkr
    case ohienko
    case synodal

    public var title: String {
        switch self {
        case .kjv: "KJV"
        case .synodal: "Синодальний"
        case .ohienko: "Огієнко"
        case .bkr: "Kralická"
        }
    }

    /// Пункт меню перекладів: назва і мова.
    public var menuTitle: String { "\(title) — \(language.title)" }

    public var language: Language {
        switch self {
        case .kjv: .english
        case .synodal: .russian
        case .ohienko: .ukrainian
        case .bkr: .czech
        }
    }

    /// Ім'я вихідного файлу в `data/raw`.
    public var sourceFileName: String {
        switch self {
        case .kjv: "en_kjv.json"
        case .synodal: "ru_synodal.json"
        case .ohienko: "uk_ohienko.json"
        case .bkr: "cs_bkr.json"
        }
    }
}
