import Foundation

/// Мова перекладу: визначає назви книг, посилання, цитати й стемер.
/// Для мов без вбудованих назв книг модуль перекладу приносить їх сам (`Translation.books`).
public enum Language: Hashable, Sendable {
    case english, russian, ukrainian, czech
    case other(String)

    public init(code: String) {
        switch code {
        case "en": self = .english
        case "ru": self = .russian
        case "uk": self = .ukrainian
        case "cs": self = .czech
        default: self = .other(code)
        }
    }

    public var code: String {
        switch self {
        case .english: "en"
        case .russian: "ru"
        case .ukrainian: "uk"
        case .czech: "cs"
        case .other(let code): code
        }
    }

    /// Мови з вбудованими назвами й скороченнями 66 книг.
    public var hasBuiltInBookNames: Bool {
        if case .other = self { return false }
        return true
    }
}

/// Переклад — модуль із маніфесту `Resources/translations.json` (FR-30): новий переклад додається
/// файлом у `data/raw` і рядком маніфесту, без змін коду. Порядок у маніфесті — порядок у меню і в ⌘⌥1…9.
/// Коди `kjv`, `bkr`, `ohienko`, `synodal` обов'язкові: на них спираються код і таблиця відповідностей.
public struct Translation: Hashable, Sendable, CaseIterable, Identifiable, CustomStringConvertible {
    /// Нумерація віршів: `kjv` або `synodal`. Інші системи (Вульгата, LXX) не підтримуються: для них
    /// потрібна власна таблиця відповідностей (tech debt #25).
    public enum Numbering: String, Codable, Sendable { case kjv, synodal }

    public struct BookName: Codable, Hashable, Sendable {
        public let name: String
        public let abbreviation: String
    }

    /// Код перекладу: ключ у базі й у налаштуваннях.
    public let rawValue: String
    public let title: String
    public let language: Language
    public let languageTitle: String
    public let numbering: Numbering
    /// Ім'я вихідного файлу в `data/raw`.
    public let sourceFileName: String
    /// Назви книг для мови без вбудованих назв (66, у порядку канону).
    public let books: [BookName]?

    public var id: String { rawValue }
    public var description: String { rawValue }

    /// Пункт меню перекладів: назва і мова.
    public var menuTitle: String { "\(title) — \(languageTitle)" }

    public init(rawValue: String, title: String, language: Language, languageTitle: String, numbering: Numbering,
                sourceFileName: String, books: [BookName]? = nil) {
        self.rawValue = rawValue
        self.title = title
        self.language = language
        self.languageTitle = languageTitle
        self.numbering = numbering
        self.sourceFileName = sourceFileName
        self.books = books
    }

    /// Переклад із каталогу за кодом.
    public init?(rawValue: String) {
        guard let found = Self.allCases.first(where: { $0.rawValue == rawValue }) else { return nil }
        self = found
    }

    public static func == (a: Translation, b: Translation) -> Bool { a.rawValue == b.rawValue }
    public func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }

    /// Каталог з вшитого маніфесту; вбудовані переклади перевіряються тестами.
    // Пошкоджений маніфест або відсутній вбудований код — помилка збірки даних, додаток без них не працює.
    public static let allCases: [Translation] = try! TranslationCatalog.load(from: TranslationCatalog.bundledManifest)

    private static func builtIn(_ code: String) -> Translation { Translation(rawValue: code)! }

    public static let kjv = builtIn("kjv")
    public static let bkr = builtIn("bkr")
    public static let ohienko = builtIn("ohienko")
    public static let synodal = builtIn("synodal")
}

/// Зберігається кодом (у налаштуваннях і базі); невідомий код — помилка декодування.
extension Translation: Codable {
    public init(from decoder: Decoder) throws {
        let code = try decoder.singleValueContainer().decode(String.self)
        guard let translation = Translation(rawValue: code) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "невідомий переклад \(code)"))
        }
        self = translation
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum TranslationCatalog {
    public enum Error: Swift.Error, Equatable, CustomStringConvertible {
        case duplicateCode(String)
        case missingBookNames(String)
        case badBookNames(String)

        public var description: String {
            switch self {
            case .duplicateCode(let code): "переклад «\(code)» у маніфесті двічі"
            case .missingBookNames(let code): "переклад «\(code)»: мова без вбудованих назв книг — потрібен список books (66)"
            case .badBookNames(let code): "переклад «\(code)»: books має містити 66 назв"
            }
        }
    }

    private struct Entry: Decodable {
        let code, title, language, languageTitle, file: String
        let numbering: Translation.Numbering
        let books: [Translation.BookName]?
    }

    public static var bundledManifest: Data {
        get throws {
            try Data(contentsOf: Bundle.module.url(forResource: "translations", withExtension: "json")!)
        }
    }

    /// Розбирає маніфест і перевіряє: коди унікальні, мова без вбудованих назв приносить 66 назв книг.
    public static func load(from data: Data) throws -> [Translation] {
        let entries = try JSONDecoder().decode([Entry].self, from: data)
        var seen = Set<String>()
        return try entries.map { entry in
            guard seen.insert(entry.code).inserted else { throw Error.duplicateCode(entry.code) }
            let language = Language(code: entry.language)
            if let books = entry.books, books.count != 66 { throw Error.badBookNames(entry.code) }
            if !language.hasBuiltInBookNames, entry.books == nil { throw Error.missingBookNames(entry.code) }
            return Translation(rawValue: entry.code, title: entry.title, language: language, languageTitle: entry.languageTitle,
                               numbering: entry.numbering, sourceFileName: entry.file, books: entry.books)
        }
    }
}

/// Скорочення ⌘⌥ для пункту меню перекладу: цифра 1…9 для перших дев'яти, далі — без скорочення.
public enum TranslationShortcut {
    public static func digit(forIndex index: Int) -> Character? {
        (0..<9).contains(index) ? Character("\(index + 1)") : nil
    }
}
