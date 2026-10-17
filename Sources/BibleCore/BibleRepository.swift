import Foundation
import GRDB

public enum RepositoryError: Error, CustomStringConvertible {
    case cannotOpen(path: String, reason: String)

    public var description: String {
        switch self {
        case .cannotOpen(let path, let reason): "Не вдалося відкрити базу \(path): \(reason)"
        }
    }
}

/// The single access point to the Bible text.
public protocol BibleRepository: Sendable {
    /// The translation's text is in the database; an optional local-only module may be absent (FR-43).
    func hasTranslation(_ translation: Translation) throws -> Bool
    func books(translation: Translation) throws -> [Book]
    func chapterCount(book: Int, translation: Translation) throws -> Int
    func verses(book: Int, chapter: Int, translation: Translation) throws -> [Verse]
    /// A page of results in book order and the total match count in the scope.
    func searchPage(_ query: String, translation: Translation, scope: SearchScope, offset: Int, limit: Int) throws -> SearchPage
}

extension BibleRepository {
    public func hasTranslation(_ translation: Translation) throws -> Bool { true }
}

public final class SQLiteBibleRepository: BibleRepository {
    private let queue: DatabaseQueue

    public init(path: URL) throws {
        var config = Configuration()
        config.readonly = true
        do {
            queue = try DatabaseQueue(path: path.path, configuration: config)
            // Opening is lazy about content: check that this is our database.
            _ = try queue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM verses LIMIT 1") }
        } catch {
            throw RepositoryError.cannotOpen(path: path.path, reason: "\(error)")
        }
    }

    public func hasTranslation(_ translation: Translation) throws -> Bool {
        try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT 1 FROM verses WHERE translation = ? LIMIT 1", arguments: [translation.rawValue]) != nil
        }
    }

    public func books(translation: Translation) throws -> [Book] {
        try queue.read { db in
            try Int.fetchAll(db, sql: "SELECT DISTINCT book FROM verses WHERE translation = ? ORDER BY book",
                             arguments: [translation.rawValue])
        }.compactMap(Book.init(number:))
    }

    public func chapterCount(book: Int, translation: Translation) throws -> Int {
        try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT MAX(chapter) FROM verses WHERE translation = ? AND book = ?",
                             arguments: [translation.rawValue, book]) ?? 0
        }
    }

    public func verses(book: Int, chapter: Int, translation: Translation) throws -> [Verse] {
        try queue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT verse, text FROM verses
                WHERE translation = ? AND book = ? AND chapter = ?
                ORDER BY verse
                """, arguments: [translation.rawValue, book, chapter])
        }.map { Verse(translation: translation, book: book, chapter: chapter, verse: $0["verse"], text: $0["text"]) }
    }

    func read<T>(_ block: (Database) throws -> T) throws -> T {
        try queue.read(block)
    }
}
