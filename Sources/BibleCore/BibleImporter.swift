import Foundation
import GRDB

public enum ImportError: Error, Equatable, CustomStringConvertible {
    case missingFile(String)
    case malformed(String)
    /// A truncated file: fewer books than in the canon (tech debt #14).
    case incomplete(String, books: Int, expected: Int)

    public var description: String {
        switch self {
        case .missingFile(let name): "Файл не знайдено: \(name)"
        case .malformed(let name): "Неочікуваний формат файлу: \(name)"
        case .incomplete(let name, let books, let expected): "Неповний файл \(name): книг \(books) з \(expected)"
        }
    }
}

/// Imports `data/raw/*.json` (thiagobodruk format) into `bible.sqlite`.
public enum BibleImporter {
    private struct SourceBook: Decodable {
        let chapters: [[String]]
    }

    /// `translations`: modules from the manifest (FR-30); the bundled catalog by default.
    /// `expectedBooks`: the minimum number of books per file (the CLI requires the whole canon; test fixtures are shorter).
    public static func run(rawDirectory: URL, output: URL, translations: [Translation] = Translation.allCases,
                           expectedBooks: Int? = nil) throws {
        // Read all sources first, so no database is created on an input data error.
        let sources = try translations.map { ($0, try load($0, from: rawDirectory)) }
        if let expectedBooks {
            for (translation, books) in sources where books.count < expectedBooks {
                throw ImportError.incomplete(translation.sourceFileName, books: books.count, expected: expectedBooks)
            }
        }

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
                try indexStems(db, translations: translations)
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

    /// Removes `{…}` italic markup and extra spaces.
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
        // JSONDecoder does not accept a BOM.
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
              search_text TEXT,
              PRIMARY KEY (translation, book, chapter, verse)
            );
            CREATE VIEW verses_search AS
              SELECT rowid AS rowid, coalesce(search_text, text) AS search_text FROM verses;
            CREATE VIRTUAL TABLE verses_fts USING fts5(
              search_text,
              content='verses_search',
              tokenize='unicode61 remove_diacritics 2'
            );
            -- Основи слів для морфологічного пошуку (FR-18); rowid = verses.rowid.
            CREATE VIRTUAL TABLE verses_stem_fts USING fts5(
              stems,
              content='',
              tokenize='unicode61 remove_diacritics 2'
            );
            """)
    }

    /// Fills `verses_stem_fts` with the word stems of every verse using the translation language's stemmer.
    private static func indexStems(_ db: Database, translations: [Translation]) throws {
        let insert = try db.makeStatement(sql: "INSERT INTO verses_stem_fts(rowid, stems) VALUES (?, ?)")
        for translation in translations {
            let stemmer = Stemmer(language: translation.language)
            let rows = try Row.fetchCursor(db, sql: "SELECT rowid, text FROM verses WHERE translation = ?", arguments: [translation.rawValue])
            while let row = try rows.next() {
                try insert.execute(arguments: [row["rowid"] as Int64, stemmer.stemmed(row["text"])])
            }
        }
    }

    private static func insert(_ books: [SourceBook], translation: Translation, into db: Database) throws {
        let statement = try db.makeStatement(sql: "INSERT INTO verses (translation, book, chapter, verse, text, search_text) VALUES (?, ?, ?, ?, ?, ?)")
        for (bookIndex, book) in books.enumerated() {
            for (chapterIndex, verses) in book.chapters.enumerated() {
                for (verseIndex, text) in verses.enumerated() {
                    let text = clean(text)
                    // An empty string is a verse missing in the source: we skip it, following numbers are kept.
                    guard !text.isEmpty else { continue }
                    let folded = SearchText.fold(text)
                    try statement.execute(arguments: [translation.rawValue, bookIndex + 1, chapterIndex + 1, verseIndex + 1, text,
                                                      folded == text ? nil : folded])
                }
            }
        }
    }
}

/// The `bible-import` CLI as a function: exit code and stderr are covered by tests.
public enum ImportCommand {
    public static func run(arguments: [String], stderr: (String) -> Void) -> Int32 {
        guard arguments.count == 3 else {
            stderr("Використання: bible-import <raw-dir> <out.sqlite>\n")
            return 64
        }
        let raw = URL(fileURLWithPath: arguments[1])
        let output = URL(fileURLWithPath: arguments[2])
        do {
            try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try BibleImporter.run(rawDirectory: raw, output: output, expectedBooks: Book.all.count)
            print("Готово: \(output.path)")
            return 0
        } catch {
            stderr("Помилка: \(error)\n")
            return 1
        }
    }
}
