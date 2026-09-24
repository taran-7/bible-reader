import GRDB

public enum SearchQuery {
    /// Кожне слово береться в лапки (синтаксис FTS5 стає текстом); слова через пробіл означають AND.
    public static func fts(_ query: String) -> String? {
        let tokens = query.split(whereSeparator: \.isWhitespace)
        guard !tokens.isEmpty else { return nil }
        return tokens.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: " ")
    }
}

public struct SearchResult: Identifiable, Hashable, Sendable {
    public struct Segment: Hashable, Sendable {
        public let text: String
        public let isMatch: Bool
    }

    public let verse: Verse
    /// Фрагмент тексту, поділений на звичайні частини і збіги.
    public let segments: [Segment]

    public var id: VerseID { verse.id }

    static let matchStart: Character = "\u{2}"
    static let matchEnd: Character = "\u{3}"

    static func segments(fromSnippet snippet: String) -> [Segment] {
        var result: [Segment] = []
        var current = ""
        var inMatch = false
        func flush() {
            if !current.isEmpty { result.append(Segment(text: current, isMatch: inMatch)) }
            current = ""
        }
        for character in snippet {
            if character == matchStart || character == matchEnd {
                flush()
                inMatch = character == matchStart
            } else {
                current.append(character)
            }
        }
        flush()
        return result
    }
}

extension SQLiteBibleRepository {
    public func search(_ query: String, translation: Translation, limit: Int = 200) throws -> [SearchResult] {
        guard let match = SearchQuery.fts(query) else { return [] }
        return try read { db in
            try Row.fetchAll(db, sql: """
                SELECT v.book, v.chapter, v.verse, v.text,
                       snippet(verses_fts, 0, char(2), char(3), '…', 16) AS snippet
                FROM verses_fts
                JOIN verses v ON v.rowid = verses_fts.rowid
                WHERE verses_fts MATCH ? AND v.translation = ?
                ORDER BY v.book, v.chapter, v.verse
                LIMIT ?
                """, arguments: [match, translation.rawValue, limit])
        }.map { row in
            SearchResult(
                verse: Verse(translation: translation, book: row["book"], chapter: row["chapter"], verse: row["verse"], text: row["text"]),
                segments: SearchResult.segments(fromSnippet: row["snippet"]))
        }
    }
}
