import Foundation
import GRDB
import Observation

/// A verse without a translation: bookmarks, highlights and notes are tied to book, chapter and verse,
/// so they survive a rebuild of `bible.sqlite` and are shared by translations with the same numbering.
public struct VerseKey: Hashable, Comparable, Codable, Sendable {
    public let book: Int
    public let chapter: Int
    public let verse: Int

    public init(book: Int, chapter: Int, verse: Int) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
    }

    public static func < (a: VerseKey, b: VerseKey) -> Bool {
        (a.book, a.chapter, a.verse) < (b.book, b.chapter, b.verse)
    }

    public var reference: Reference { Reference(book: book, chapter: chapter, verseStart: verse) }
}

/// Verse highlight colors (FR-23).
public enum HighlightColor: String, CaseIterable, Codable, Sendable {
    case yellow, green, blue, pink

    public var title: String {
        switch self {
        case .yellow: "жовтий"
        case .green: "зелений"
        case .blue: "блакитний"
        case .pink: "рожевий"
        }
    }
}

/// A bookmark on a verse or a whole chapter (`verse == nil`), FR-22.
public struct Bookmark: Hashable, Codable, Sendable, Identifiable {
    public struct Target: Hashable, Comparable, Codable, Sendable {
        public let book: Int
        public let chapter: Int
        public let verse: Int?

        public init(book: Int, chapter: Int, verse: Int?) {
            self.book = book
            self.chapter = chapter
            self.verse = verse
        }

        public static func < (a: Target, b: Target) -> Bool {
            (a.book, a.chapter, a.verse ?? 0) < (b.book, b.chapter, b.verse ?? 0)
        }

        public var reference: Reference { Reference(book: book, chapter: chapter, verseStart: verse) }
    }

    public let target: Target
    public let created: Date
    public var id: Target { target }
}

/// A verse note (FR-24).
public struct Note: Hashable, Codable, Sendable, Identifiable {
    public let key: VerseKey
    public let text: String
    public let updated: Date
    public var id: VerseKey { key }
}

/// What to show next to a verse in the text.
public struct VerseMarks: Equatable, Sendable {
    public var highlight: HighlightColor?
    public var hasNote = false
    public var isBookmarked = false

    public init(highlight: HighlightColor? = nil, hasNote: Bool = false, isBookmarked: Bool = false) {
        self.highlight = highlight
        self.hasNote = hasNote
        self.isBookmarked = isBookmarked
    }
}

/// The JSON export format.
public struct UserDataExport: Codable, Equatable, Sendable {
    public struct Highlight: Codable, Equatable, Sendable {
        public let key: VerseKey
        public let color: HighlightColor
    }

    public var version = 1
    public let bookmarks: [Bookmark]
    public let highlights: [Highlight]
    public let notes: [Note]
}

extension JSONEncoder {
    static var userData: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

extension JSONDecoder {
    static var userData: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

/// A separate local user database (not the read-only `bible.sqlite`).
public final class UserDatabase: Sendable {
    let queue: DatabaseQueue

    public init(path: URL) throws {
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        queue = try DatabaseQueue(path: path.path)
        try Self.migrator.migrate(queue)
    }

    private init(queue: DatabaseQueue) throws {
        self.queue = queue
        try Self.migrator.migrate(queue)
    }

    public static func inMemory() throws -> UserDatabase {
        try UserDatabase(queue: DatabaseQueue())
    }

    /// The default location: the app's Application Support (in the sandbox, the app container).
    /// `profile` is a separate subfolder (UI tests take a fresh one on every run).
    public static func defaultURL(profile: String? = nil) throws -> URL {
        var folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Bible Reader", isDirectory: true)
        if let profile { folder.appendPathComponent(profile, isDirectory: true) }
        return folder.appendingPathComponent("userdata.sqlite")
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            // verse = 0 means a bookmark on the whole chapter.
            try db.execute(sql: """
                CREATE TABLE bookmark (
                  book INTEGER NOT NULL, chapter INTEGER NOT NULL, verse INTEGER NOT NULL,
                  created REAL NOT NULL,
                  PRIMARY KEY (book, chapter, verse)
                );
                CREATE TABLE highlight (
                  book INTEGER NOT NULL, chapter INTEGER NOT NULL, verse INTEGER NOT NULL,
                  color TEXT NOT NULL,
                  PRIMARY KEY (book, chapter, verse)
                );
                CREATE TABLE note (
                  book INTEGER NOT NULL, chapter INTEGER NOT NULL, verse INTEGER NOT NULL,
                  text TEXT NOT NULL, updated REAL NOT NULL,
                  PRIMARY KEY (book, chapter, verse)
                );
                -- Дрібний стан (останнє місце читання, FR-25).
                CREATE TABLE state (key TEXT PRIMARY KEY, value BLOB NOT NULL);
                """)
        }
        // Sermon drafts (FR-38).
        migrator.registerMigration("v2") { db in
            try db.execute(sql: """
                CREATE TABLE draft (
                  id TEXT PRIMARY KEY, title TEXT NOT NULL, text TEXT NOT NULL,
                  created REAL NOT NULL, updated REAL NOT NULL
                );
                """)
        }
        return migrator
    }
}

/// State in the same database, so the last position lives next to the notes (and in UI tests resets together with them).
/// Read errors give `nil`, write errors are ignored: this is only a convenience.
extension UserDatabase: KeyValueStore {
    public func data(forKey key: String) -> Data? {
        try? queue.read { try Data.fetchOne($0, sql: "SELECT value FROM state WHERE key = ?", arguments: [key]) }
    }

    public func set(_ data: Data, forKey key: String) {
        try? queue.write { try $0.execute(sql: "INSERT OR REPLACE INTO state (key, value) VALUES (?, ?)", arguments: [key, data]) }
    }

    public func removeObject(forKey key: String) {
        try? queue.write { try $0.execute(sql: "DELETE FROM state WHERE key = ?", arguments: [key]) }
    }
}

/// Bookmarks, highlights and notes for SwiftUI: everything in memory, every change is written to the database immediately.
@MainActor @Observable
public final class UserData {
    public private(set) var bookmarks: [Bookmark] = []
    public private(set) var highlights: [VerseKey: HighlightColor] = [:]
    public private(set) var notes: [VerseKey: Note] = [:]
    /// The last database write or read error; the data in memory stays.
    public private(set) var lastError: String?

    @ObservationIgnored private let database: UserDatabase?
    @ObservationIgnored private let now: () -> Date

    public init(database: UserDatabase?, now: @escaping () -> Date = Date.init) {
        self.database = database
        self.now = now
        load()
    }

    /// The database could not be opened: work in memory and show the reason.
    public convenience init(unavailable error: any Error) {
        self.init(database: nil)
        lastError = "\(error)"
    }

    // MARK: Bookmarks

    public func isBookmarked(_ target: Bookmark.Target) -> Bool {
        bookmarks.contains { $0.target == target }
    }

    public func toggleBookmark(_ target: Bookmark.Target) {
        let verse = target.verse ?? 0
        if isBookmarked(target) {
            guard write([("DELETE FROM bookmark WHERE book = ? AND chapter = ? AND verse = ?", [target.book, target.chapter, verse])])
            else { return }
            bookmarks.removeAll { $0.target == target }
        } else {
            let bookmark = Bookmark(target: target, created: now())
            guard write([("INSERT OR REPLACE INTO bookmark (book, chapter, verse, created) VALUES (?, ?, ?, ?)",
                          [target.book, target.chapter, verse, bookmark.created.timeIntervalSince1970])])
            else { return }
            bookmarks.append(bookmark)
            bookmarks.sort { $0.target < $1.target }
        }
    }

    // MARK: Highlights

    public func highlight(for key: VerseKey) -> HighlightColor? { highlights[key] }

    /// `nil` removes the highlight.
    public func setHighlight(_ color: HighlightColor?, for keys: some Collection<VerseKey>) {
        // All verses in one transaction; memory changes only after a successful write.
        let statements: [(String, StatementArguments)] = keys.map { key in
            if let color {
                ("INSERT OR REPLACE INTO highlight (book, chapter, verse, color) VALUES (?, ?, ?, ?)",
                 [key.book, key.chapter, key.verse, color.rawValue])
            } else {
                ("DELETE FROM highlight WHERE book = ? AND chapter = ? AND verse = ?", [key.book, key.chapter, key.verse])
            }
        }
        guard write(statements) else { return }
        for key in keys { highlights[key] = color }
    }

    // MARK: Notes

    public func note(for key: VerseKey) -> Note? { notes[key] }

    /// Empty text deletes the note.
    public func setNote(_ text: String, for key: VerseKey) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            guard write([("DELETE FROM note WHERE book = ? AND chapter = ? AND verse = ?", [key.book, key.chapter, key.verse])])
            else { return }
            notes[key] = nil
        } else {
            let note = Note(key: key, text: text, updated: now())
            guard write([("INSERT OR REPLACE INTO note (book, chapter, verse, text, updated) VALUES (?, ?, ?, ?, ?)",
                          [key.book, key.chapter, key.verse, text, note.updated.timeIntervalSince1970])])
            else { return }
            notes[key] = note
        }
    }

    /// Notes containing the query (ignoring case and «ё»), in book order.
    public func searchNotes(_ query: String) -> [Note] {
        let needle = SearchText.fold(query.trimmingCharacters(in: .whitespacesAndNewlines)).lowercased()
        guard !needle.isEmpty else { return [] }
        return notes.values
            .filter { SearchText.fold($0.text).lowercased().contains(needle) }
            .sorted { $0.key < $1.key }
    }

    public var sortedNotes: [Note] { notes.values.sorted { $0.key < $1.key } }

    // MARK: Chapter marks

    /// Marks of a verse made of one or more KJV verses (merged in the Synodal).
    public func marks(for keys: [VerseKey]) -> VerseMarks {
        var marks = VerseMarks()
        for key in keys {
            marks.highlight = marks.highlight ?? highlights[key]
            marks.hasNote = marks.hasNote || notes[key] != nil
            marks.isBookmarked = marks.isBookmarked || bookmarkTargets.contains(.init(book: key.book, chapter: key.chapter, verse: key.verse))
        }
        return marks
    }

    public func marks(for key: VerseKey) -> VerseMarks { marks(for: [key]) }

    /// A set for a quick check in every chapter row.
    private var bookmarkTargets: Set<Bookmark.Target> { Set(bookmarks.map(\.target)) }

    public func marks(book: Int, chapter: Int) -> [Int: VerseMarks] {
        var marks: [Int: VerseMarks] = [:]
        for (key, color) in highlights where key.book == book && key.chapter == chapter {
            marks[key.verse, default: VerseMarks()].highlight = color
        }
        for key in notes.keys where key.book == book && key.chapter == chapter {
            marks[key.verse, default: VerseMarks()].hasNote = true
        }
        for bookmark in bookmarks where bookmark.target.book == book && bookmark.target.chapter == chapter {
            if let verse = bookmark.target.verse { marks[verse, default: VerseMarks()].isBookmarked = true }
        }
        return marks
    }

    // MARK: Export

    public func exportJSON() throws -> Data {
        let export = UserDataExport(
            bookmarks: bookmarks,
            highlights: highlights.sorted { $0.key < $1.key }.map { .init(key: $0.key, color: $0.value) },
            notes: sortedNotes)
        return try JSONEncoder.userData.encode(export)
    }

    /// Markdown with references in the on-screen translation's language.
    public func exportMarkdown(in translation: Translation) -> String {
        var lines = ["# Bible Reader: закладки, підсвітки, нотатки", ""]
        lines.append("## Закладки")
        lines += bookmarks.map { "- \($0.target.reference.format(in: translation))" }
        lines += ["", "## Підсвітки"]
        lines += highlights.sorted { $0.key < $1.key }.map { "- \($0.key.reference.format(in: translation)) — \($0.value.title)" }
        lines += ["", "## Нотатки"]
        for note in sortedNotes {
            lines += ["", "### \(note.key.reference.format(in: translation))", "", note.text]
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: Database

    private func load() {
        guard let database else { return }
        do {
            try database.queue.read { db in
                bookmarks = try Row.fetchAll(db, sql: "SELECT * FROM bookmark ORDER BY book, chapter, verse").map { row in
                    let verse: Int = row["verse"]
                    return Bookmark(target: .init(book: row["book"], chapter: row["chapter"], verse: verse == 0 ? nil : verse),
                                    created: Date(timeIntervalSince1970: row["created"]))
                }
                for row in try Row.fetchAll(db, sql: "SELECT * FROM highlight") {
                    if let color = HighlightColor(rawValue: row["color"]) {
                        highlights[VerseKey(book: row["book"], chapter: row["chapter"], verse: row["verse"])] = color
                    }
                }
                for row in try Row.fetchAll(db, sql: "SELECT * FROM note") {
                    let key = VerseKey(book: row["book"], chapter: row["chapter"], verse: row["verse"])
                    notes[key] = Note(key: key, text: row["text"], updated: Date(timeIntervalSince1970: row["updated"]))
                }
            }
        } catch {
            lastError = "\(error)"
        }
    }

    /// One transaction; `false` means the write failed, the in-memory state is not changed. Without a database, memory only.
    private func write(_ statements: [(String, StatementArguments)]) -> Bool {
        guard let database else { return true }
        do {
            try database.queue.write { db in
                for (sql, arguments) in statements { try db.execute(sql: sql, arguments: arguments) }
            }
            return true
        } catch {
            lastError = "\(error)"
            return false
        }
    }

    /// The user dismissed the error message.
    public func dismissError() { lastError = nil }

    /// Changes live only until exit: the database could not be opened.
    public var isInMemoryOnly: Bool { database == nil }
}
