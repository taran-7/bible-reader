import Foundation
import GRDB

public enum ImportError: Error, Equatable, CustomStringConvertible {
    case missingFile(String)
    case malformed(String)

    public var description: String {
        switch self {
        case .missingFile(let name): "Файл не знайдено: \(name)"
        case .malformed(let name): "Неочікуваний формат файлу: \(name)"
        }
    }
}

/// Імпорт `data/raw/*.json` (формат thiagobodruk) у `bible.sqlite`.
public enum BibleImporter {
    private struct SourceBook: Decodable {
        let chapters: [[String]]
    }

    public static func run(rawDirectory: URL, output: URL) throws {
        // Спочатку читаємо всі джерела, щоб не створювати базу при помилці вхідних даних.
        let sources = try Translation.allCases.map { ($0, try load($0, from: rawDirectory)) }

        let fm = FileManager.default
        let tmp = URL(fileURLWithPath: output.path + ".tmp")
        try? fm.removeItem(at: tmp)
        do {
            let queue = try DatabaseQueue(path: tmp.path)
            try queue.write { db in
                try createSchema(db)
                for (translation, books) in sources {
                    try insert(books, translation: translation, into: db)
                }
                try db.execute(sql: "INSERT INTO verses_fts(verses_fts) VALUES('rebuild')")
            }
            try queue.close()
            if fm.fileExists(atPath: output.path) {
                _ = try fm.replaceItemAt(output, withItemAt: tmp)
            } else {
                try fm.moveItem(at: tmp, to: output)
            }
        } catch {
            try? fm.removeItem(at: tmp)
            throw error
        }
    }

    /// Прибирає курсивну розмітку `{…}` і зайві пробіли.
    static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func load(_ translation: Translation, from dir: URL) throws -> [SourceBook] {
        let name = translation.sourceFileName
        let url = dir.appendingPathComponent(name)
        guard let data = FileManager.default.contents(atPath: url.path) else {
            throw ImportError.missingFile(name)
        }
        // JSONDecoder не приймає BOM.
        let bom = Data([0xEF, 0xBB, 0xBF])
        let body = data.starts(with: bom) ? data.dropFirst(3) : data
        do {
            return try JSONDecoder().decode([SourceBook].self, from: Data(body))
        } catch {
            throw ImportError.malformed(name)
        }
    }

    private static func createSchema(_ db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE verses (
              translation TEXT    NOT NULL,
              book        INTEGER NOT NULL,
              chapter     INTEGER NOT NULL,
              verse       INTEGER NOT NULL,
              text        TEXT    NOT NULL,
              PRIMARY KEY (translation, book, chapter, verse)
            );
            CREATE VIRTUAL TABLE verses_fts USING fts5(
              text,
              content='verses',
              tokenize='unicode61 remove_diacritics 2'
            );
            """)
    }

    private static func insert(_ books: [SourceBook], translation: Translation, into db: Database) throws {
        let statement = try db.makeStatement(sql: "INSERT INTO verses (translation, book, chapter, verse, text) VALUES (?, ?, ?, ?, ?)")
        for (bookIndex, book) in books.enumerated() {
            for (chapterIndex, verses) in book.chapters.enumerated() {
                for (verseIndex, text) in verses.enumerated() {
                    try statement.execute(arguments: [translation.rawValue, bookIndex + 1, chapterIndex + 1, verseIndex + 1, clean(text)])
                }
            }
        }
    }
}
