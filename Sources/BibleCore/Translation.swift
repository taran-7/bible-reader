import Foundation

/// The translation language: sets book names, references, quotes and the stemmer.
/// For languages without built-in book names the translation module brings them itself (`Translation.books`).
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

    /// Languages with built-in names and abbreviations of the 66 books.
    public var hasBuiltInBookNames: Bool {
        if case .other = self { return false }
        return true
    }
}

/// A translation is a module from the `Resources/translations.json` manifest (FR-30): a new translation is added
/// with a file in `data/raw` and a manifest line, without code changes. Manifest order is the order in the menu and in ⌘⌥1…9.
/// The codes `kjv`, `bkr`, `ohienko`, `synodal` are required: the code and the mapping table rely on them.
public struct Translation: Hashable, Sendable, CaseIterable, Identifiable, CustomStringConvertible {
    /// A verse numbering system. `kjv` is the hub: every other system has a mapping table to KJV,
    /// and between two non-KJV systems a verse goes through KJV. `synodal` has a built-in table; a new system
    /// (Vulgate, LXX) brings its own in the manifest via the `versification` field (tech debt #25).
    public struct Numbering: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(stringLiteral value: String) { self.rawValue = value }
        public static let kjv: Numbering = "kjv"
        public static let synodal: Numbering = "synodal"
        /// Systems with a table in code: the manifest does not have to bring a table for them.
        public var isBuiltIn: Bool { self == .kjv || self == .synodal }
    }

    public struct BookName: Codable, Hashable, Sendable {
        public let name: String
        public let abbreviation: String
    }

    /// The translation code: the key in the database and in settings.
    public let rawValue: String
    public let title: String
    public let language: Language
    public let languageTitle: String
    public let numbering: Numbering
    /// The source file name in `data/raw`.
    public let sourceFileName: String
    /// Book names for a language without built-in names (66, in canonical order).
    public let books: [BookName]?
    /// The mapping table to KJV for a new numbering system (from the manifest).
    public let versificationTable: VersificationTable?

    public var id: String { rawValue }
    public var description: String { rawValue }

    /// A translation menu item: title and language.
    public var menuTitle: String { "\(title) — \(languageTitle)" }

    public init(rawValue: String, title: String, language: Language, languageTitle: String, numbering: Numbering,
                sourceFileName: String, books: [BookName]? = nil, versificationTable: VersificationTable? = nil) {
        self.rawValue = rawValue
        self.title = title
        self.language = language
        self.languageTitle = languageTitle
        self.numbering = numbering
        self.sourceFileName = sourceFileName
        self.books = books
        self.versificationTable = versificationTable
    }

    /// A translation from the catalog by code.
    public init?(rawValue: String) {
        guard let found = Self.allCases.first(where: { $0.rawValue == rawValue }) else { return nil }
        self = found
    }

    public static func == (a: Translation, b: Translation) -> Bool { a.rawValue == b.rawValue }
    public func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }

    /// The catalog from the bundled manifest; built-in translations are checked by tests.
    // A corrupted manifest or a missing built-in code is a data build error; the app does not work without them.
    public static let allCases: [Translation] = try! TranslationCatalog.load(from: TranslationCatalog.bundledManifest)

    private static func builtIn(_ code: String) -> Translation { Translation(rawValue: code)! }

    public static let kjv = builtIn("kjv")
    public static let bkr = builtIn("bkr")
    public static let ohienko = builtIn("ohienko")
    public static let synodal = builtIn("synodal")
}

/// Stored by code (in settings and the database); an unknown code is a decoding error.
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
        case missingVersification(String)

        public var description: String {
            switch self {
            case .duplicateCode(let code): "переклад «\(code)» у маніфесті двічі"
            case .missingBookNames(let code): "переклад «\(code)»: мова без вбудованих назв книг — потрібен список books (66)"
            case .badBookNames(let code): "переклад «\(code)»: books має містити 66 назв"
            case .missingVersification(let code):
                "переклад «\(code)»: нова система нумерації без таблиці відповідностей — потрібне поле versification"
            }
        }
    }

    private struct Entry: Decodable {
        let code, title, language, languageTitle, file: String
        let numbering: Translation.Numbering
        let books: [Translation.BookName]?
        let versification: VersificationTable?
    }

    public static var bundledManifest: Data {
        get throws {
            try Data(contentsOf: Bundle.module.url(forResource: "translations", withExtension: "json")!)
        }
    }

    /// Parses the manifest and checks: codes are unique, a language without built-in names brings 66 book names,
    /// a new numbering system has a mapping table in at least one module.
    public static func load(from data: Data) throws -> [Translation] {
        let entries = try JSONDecoder().decode([Entry].self, from: data)
        let tabled = Set(entries.filter { $0.versification != nil }.map(\.numbering))
        var seen = Set<String>()
        return try entries.map { entry in
            guard seen.insert(entry.code).inserted else { throw Error.duplicateCode(entry.code) }
            if !entry.numbering.isBuiltIn, !tabled.contains(entry.numbering) { throw Error.missingVersification(entry.code) }
            let language = Language(code: entry.language)
            if let books = entry.books, books.count != 66 { throw Error.badBookNames(entry.code) }
            if !language.hasBuiltInBookNames, entry.books == nil { throw Error.missingBookNames(entry.code) }
            return Translation(rawValue: entry.code, title: entry.title, language: language, languageTitle: entry.languageTitle,
                               numbering: entry.numbering, sourceFileName: entry.file, books: entry.books,
                               versificationTable: entry.versification)
        }
    }
}

/// The ⌘⌥ shortcut for a translation menu item: digit 1…9 for the first nine, none after that.
public enum TranslationShortcut {
    public static func digit(forIndex index: Int) -> Character? {
        (0..<9).contains(index) ? Character("\(index + 1)") : nil
    }

    /// Physical digit-row keys 1…9 (ANSI codes). On the Czech layout the row without Shift gives
    /// `+ ě š č`, so ⌘⌥1…9 is caught by key code, not by character (tech debt #23).
    static let digitKeyCodes: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25]

    /// The translation index for a digit-row key; `nil` means another key.
    public static func index(forKeyCode keyCode: UInt16) -> Int? {
        digitKeyCodes.firstIndex(of: keyCode)
    }
}
