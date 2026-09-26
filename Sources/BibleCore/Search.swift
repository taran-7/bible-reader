import GRDB

/// Згортання для пошуку: `unicode61 remove_diacritics` згортає лише латиницю,
/// тож «ё → е» робимо самі. Заміна символ-на-символ, тому позиції у згорнутому
/// і оригінальному тексті збігаються.
public enum SearchText {
    public static func fold(_ text: String) -> String {
        String(text.map { $0 == "ё" ? "е" : $0 == "Ё" ? "Е" : $0 })
    }
}

public enum SearchQuery {
    /// Кожне слово береться в лапки (синтаксис FTS5 стає текстом); слова через пробіл означають AND.
    public static func fts(_ query: String) -> String? {
        let tokens = SearchText.fold(query).split(whereSeparator: \.isWhitespace)
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

    /// Сегменти з фрагмента по згорнутому тексту, з символами, повернутими з `original`.
    static func segments(fromSnippet snippet: String, original: String) -> [Segment] {
        let segments = segments(fromSnippet: snippet)
        var core = Array(segments.map(\.text).joined())
        let leading = core.first == ellipsis ? 1 : 0
        let trailing = core.count > leading && core.last == ellipsis ? 1 : 0
        core = Array(core[leading..<(core.count - trailing)])
        let folded = Array(SearchText.fold(original))
        let source = Array(original)
        guard folded.count == source.count, !core.isEmpty, core.count <= folded.count,
              let start = (0...(folded.count - core.count)).first(where: { folded[$0..<($0 + core.count)].elementsEqual(core) })
        else { return segments }
        var position = -leading
        return segments.map { segment in
            Segment(text: String(segment.text.map { character -> Character in
                defer { position += 1 }
                return position >= 0 && position < core.count ? source[start + position] : character
            }), isMatch: segment.isMatch)
        }
    }

    static let ellipsis: Character = "…"

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
                segments: SearchResult.segments(fromSnippet: row["snippet"], original: row["text"]))
        }
    }
}
