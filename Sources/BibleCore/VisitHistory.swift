import Foundation
import GRDB
import Observation

/// A visited place (FR-42): a verse, or a whole chapter when it was only opened (`verse == nil`).
/// Stored in the translation's own numbering: a click reopens exactly that translation, so nothing is mapped.
public struct VisitEntry: Hashable, Identifiable, Sendable {
    public let translation: Translation
    public let book: Int
    public let chapter: Int
    public let verse: Int?

    public init(translation: Translation, book: Int, chapter: Int, verse: Int?) {
        self.translation = translation
        self.book = book
        self.chapter = chapter
        self.verse = verse
    }

    /// Identity is translation + place: the same visit moves to the top instead of duplicating.
    public var id: String { "\(translation.rawValue):\(book):\(chapter):\(verse ?? 0)" }

    /// A row: the book's name in the translation's language and the place, `От Иоанна 3:16`; no translation label.
    public var title: String {
        let name = Book(number: book)?.name(in: translation) ?? "\(book)"
        return "\(name) \(chapter)" + (verse.map { ":\($0)" } ?? "")
    }
}

/// Recently visited verses, newest first (FR-42): deduplicated, at most `limit`, written to the user database at once.
/// Errors are ignored like the saved reading position (a convenience); without a database the list lives in memory.
@MainActor @Observable
public final class VisitHistory {
    public static let limit = 50

    public private(set) var entries: [VisitEntry] = []
    @ObservationIgnored private let database: UserDatabase?

    public init(database: UserDatabase?) {
        self.database = database
        load()
    }

    /// The same translation and place moves to the top; past the limit the oldest entry is dropped.
    public func record(_ entry: VisitEntry) {
        entries.removeAll { $0 == entry }
        entries.insert(entry, at: 0)
        if entries.count > Self.limit { entries.removeLast(entries.count - Self.limit) }
        write { db in
            let key: [any DatabaseValueConvertible] = [entry.translation.rawValue, entry.book, entry.chapter, entry.verse ?? 0]
            try db.execute(sql: "DELETE FROM visit WHERE translation = ? AND book = ? AND chapter = ? AND verse = ?",
                           arguments: StatementArguments(key))
            try db.execute(sql: "INSERT INTO visit (translation, book, chapter, verse) VALUES (?, ?, ?, ?)",
                           arguments: StatementArguments(key))
            try db.execute(sql: "DELETE FROM visit WHERE id NOT IN (SELECT id FROM visit ORDER BY id DESC LIMIT \(Self.limit))")
        }
    }

    public func clear() {
        entries = []
        write { try $0.execute(sql: "DELETE FROM visit") }
    }

    private func load() {
        guard let database else { return }
        let rows = (try? database.queue.read { db in
            try Row.fetchAll(db, sql: "SELECT translation, book, chapter, verse FROM visit ORDER BY id DESC LIMIT \(Self.limit)")
        }) ?? []
        // A code no longer in the manifest loses only that row.
        entries = rows.compactMap { row in
            guard let translation = Translation(rawValue: row["translation"]) else { return nil }
            let verse: Int = row["verse"]
            return VisitEntry(translation: translation, book: row["book"], chapter: row["chapter"], verse: verse == 0 ? nil : verse)
        }
    }

    private func write(_ block: @escaping (Database) throws -> Void) {
        guard let database else { return }
        try? database.queue.write(block)
    }
}
