import Foundation
import GRDB

/// Згортання для пошуку: `unicode61 remove_diacritics` згортає лише латиницю,
/// тож «ё → е» робимо самі; типографські апострофи (’ ʼ ‘) → ' — інакше `пʼять`
/// стає одним токеном. Заміна символ-на-символ, тому позиції у згорнутому
/// і оригінальному тексті збігаються.
public enum SearchText {
    public static func fold(_ text: String) -> String {
        String(text.map { character in
            switch character {
            case "ё": "е"
            case "Ё": "Е"
            case "’", "ʼ", "‘": "'"
            default: character
            }
        })
    }

    /// Слово, як його порівнює індекс: згорнуте, у нижньому регістрі, без діакритики латиниці.
    static func key(_ word: String) -> String {
        fold(word).lowercased().folding(options: .diacriticInsensitive, locale: nil)
    }
}

/// Область пошуку (FR-19).
public enum SearchScope: Hashable, Sendable {
    case bible, oldTestament, newTestament
    case book(Int)

    public var books: ClosedRange<Int> {
        switch self {
        case .bible: 1...66
        case .oldTestament: 1...39
        case .newTestament: 40...66
        case .book(let number): number...number
        }
    }
}

/// Розібраний запит: слова без лапок шукаються за основами (FR-18),
/// текст у лапках — точною фразою (FR-21). Непарна лапка — звичайний символ.
public struct SearchQuery: Equatable, Sendable {
    public var words: [String]
    public var phrases: [[String]]

    private static let closing: [Character: Set<Character>] = [
        "\"": ["\""], "«": ["»"], "„": ["“", "”"], "“": ["”"],
    ]

    public static func parse(_ text: String) -> SearchQuery? {
        var loose = ""
        var phrases: [[String]] = []
        var rest = Substring(text)
        while let open = rest.firstIndex(where: { closing[$0] != nil }) {
            loose += rest[..<open]
            let afterOpen = rest.index(after: open)
            if let close = rest[afterOpen...].firstIndex(where: closing[rest[open]]!.contains) {
                let words = Stemmer.words(in: String(rest[afterOpen..<close])).map { SearchText.fold($0.text).lowercased() }
                if !words.isEmpty { phrases.append(words) }
                rest = rest[rest.index(after: close)...]
            } else {
                loose += " "
                rest = rest[afterOpen...]
            }
        }
        loose += rest
        let words = Stemmer.words(in: loose).map { SearchText.fold($0.text).lowercased() }
        guard !words.isEmpty || !phrases.isEmpty else { return nil }
        return SearchQuery(words: words, phrases: phrases)
    }

    /// Кожне слово в лапках FTS5 (синтаксис FTS5 стає текстом); через пробіл — AND.
    static func fts(words: [String]) -> String {
        words.map(quoted).joined(separator: " ")
    }

    /// Кожна фраза — один рядок у лапках FTS5, тобто слова поспіль.
    static func fts(phrases: [[String]]) -> String {
        phrases.map { quoted($0.joined(separator: " ")) }.joined(separator: " ")
    }

    private static func quoted(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

public struct SearchResult: Identifiable, Hashable, Sendable {
    public struct Segment: Hashable, Sendable {
        public let text: String
        public let isMatch: Bool
    }

    public let verse: Verse
    /// Повний текст вірша, поділений на звичайні частини і збіги.
    public let segments: [Segment]

    public var id: VerseID { verse.id }

    /// Підсвічує слова, чия основа є в запиті, і слова з фраз у лапках.
    static func segments(for text: String, query: SearchQuery, stemmer: Stemmer) -> [Segment] {
        let stems = Set(query.words.map(stemmer.stem))
        let exact = Set(query.phrases.joined().map(SearchText.key))
        var segments: [Segment] = []
        var position = text.startIndex
        for word in Stemmer.words(in: text)
        where stems.contains(stemmer.stem(word.text)) || exact.contains(SearchText.key(word.text)) {
            if position < word.range.lowerBound {
                segments.append(Segment(text: String(text[position..<word.range.lowerBound]), isMatch: false))
            }
            segments.append(Segment(text: word.text, isMatch: true))
            position = word.range.upperBound
        }
        if position < text.endIndex {
            segments.append(Segment(text: String(text[position...]), isMatch: false))
        }
        return segments
    }
}

/// Сторінка результатів і загальна кількість збігів в області (FR-20).
public struct SearchPage: Sendable {
    public let results: [SearchResult]
    public let total: Int

    public init(results: [SearchResult], total: Int) {
        self.results = results
        self.total = total
    }

    public static let empty = SearchPage(results: [], total: 0)
}

extension BibleRepository {
    /// Перша сторінка результатів по всій Біблії.
    public func search(_ query: String, translation: Translation, limit: Int = 200) throws -> [SearchResult] {
        try searchPage(query, translation: translation, scope: .bible, offset: 0, limit: limit).results
    }
}

extension SQLiteBibleRepository {
    public func searchPage(_ text: String, translation: Translation, scope: SearchScope, offset: Int, limit: Int) throws -> SearchPage {
        guard let query = SearchQuery.parse(text) else { return .empty }
        let stemmer = Stemmer(language: translation.language)
        var filters = ["v.translation = ?", "v.book BETWEEN ? AND ?"]
        var arguments: StatementArguments = [translation.rawValue, scope.books.lowerBound, scope.books.upperBound]
        if !query.words.isEmpty {
            filters.append("v.rowid IN (SELECT rowid FROM verses_stem_fts WHERE verses_stem_fts MATCH ?)")
            _ = arguments.append(contentsOf: [SearchQuery.fts(words: query.words.map(stemmer.stem))])
        }
        if !query.phrases.isEmpty {
            filters.append("v.rowid IN (SELECT rowid FROM verses_fts WHERE verses_fts MATCH ?)")
            _ = arguments.append(contentsOf: [SearchQuery.fts(phrases: query.phrases)])
        }
        let whereClause = filters.joined(separator: " AND ")
        return try read { db in
            // COUNT(*) завжди повертає один рядок.
            let total = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM verses v WHERE \(whereClause)", arguments: arguments)!
            // rowid іде в порядку імпорту, тобто в порядку книг, розділів і віршів.
            let rows = try Row.fetchAll(db, sql: """
                SELECT v.book, v.chapter, v.verse, v.text FROM verses v
                WHERE \(whereClause)
                ORDER BY v.rowid
                LIMIT ? OFFSET ?
                """, arguments: arguments + [limit, offset])
            let results = rows.map { row in
                let verse = Verse(translation: translation, book: row["book"], chapter: row["chapter"], verse: row["verse"], text: row["text"])
                return SearchResult(verse: verse, segments: SearchResult.segments(for: verse.text, query: query, stemmer: stemmer))
            }
            return SearchPage(results: results, total: total)
        }
    }
}
