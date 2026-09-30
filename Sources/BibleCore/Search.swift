import Foundation
import GRDB

/// Folding for search: `unicode61 remove_diacritics` folds only Latin,
/// so we do «ё → е» ourselves; typographic apostrophes (’ ʼ ‘) → ', otherwise `пʼять`
/// becomes one token. The replacement is character for character, so positions in the folded
/// and the original text match.
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

    /// A word as the index compares it: folded, lowercase, without Latin diacritics.
    static func key(_ word: String) -> String {
        fold(word).lowercased().folding(options: .diacriticInsensitive, locale: nil)
    }
}

/// Search scope (FR-19).
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

/// A parsed query: unquoted words are searched by stems (FR-18),
/// quoted text as an exact phrase (FR-21). An unpaired quote is a plain character.
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

    /// Each word in FTS5 quotes (FTS5 syntax becomes text); separated by a space, AND.
    static func fts(words: [String]) -> String {
        words.map(quoted).joined(separator: " ")
    }

    /// Each phrase is one string in FTS5 quotes, i.e. the words in a row.
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
    /// The full verse text, split into plain parts and matches.
    public let segments: [Segment]

    public var id: VerseID { verse.id }

    /// Highlights words whose stem is in the query, and quoted phrases only where the words stand in a row.
    static func segments(for text: String, query: SearchQuery, stemmer: Stemmer) -> [Segment] {
        let stems = Set(query.words.map(stemmer.stem))
        let words = Stemmer.words(in: text)
        let keys = words.map { SearchText.key($0.text) }
        var matched = words.indices.map { stems.contains(stemmer.stem(words[$0].text)) }
        for phrase in query.phrases.map({ $0.map(SearchText.key) }) where phrase.count <= keys.count {
            for start in 0...(keys.count - phrase.count) where keys[start..<(start + phrase.count)].elementsEqual(phrase) {
                for index in start..<(start + phrase.count) { matched[index] = true }
            }
        }
        var segments: [Segment] = []
        var position = text.startIndex
        for (index, word) in words.enumerated() where matched[index] {
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

/// A page of results and the total match count in the scope (FR-20).
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
    /// The first page of results over the whole Bible.
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
            // COUNT(*) always returns one row.
            let total = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM verses v WHERE \(whereClause)", arguments: arguments)!
            // rowid follows import order, i.e. the order of books, chapters and verses.
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
