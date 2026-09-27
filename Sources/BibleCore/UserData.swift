import Foundation
import GRDB
import Observation

/// Вірш без перекладу: закладки, підсвітки й нотатки прив'язані до книги, розділу й вірша,
/// тож переживають перебудову `bible.sqlite` і спільні для перекладів з однаковою нумерацією.
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

/// Кольори підсвітки віршів (FR-23).
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

/// Закладка на вірш або на весь розділ (`verse == nil`), FR-22.
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

/// Нотатка до вірша (FR-24).
public struct Note: Hashable, Codable, Sendable, Identifiable {
    public let key: VerseKey
    public let text: String
    public let updated: Date
    public var id: VerseKey { key }
}

/// Що показати біля вірша в тексті.
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

/// Формат експорту в JSON.
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

/// Окрема локальна база користувача (не `bible.sqlite`, яка read-only).
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

    /// Стандартне місце: Application Support додатка (у пісочниці — контейнер додатка).
    /// `profile` — окрема підтека (UI-тести беруть свіжу на кожен запуск).
    public static func defaultURL(profile: String? = nil) throws -> URL {
        var folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Bible Reader", isDirectory: true)
        if let profile { folder.appendPathComponent(profile, isDirectory: true) }
        return folder.appendingPathComponent("userdata.sqlite")
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            // verse = 0 — закладка на весь розділ.
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
        return migrator
    }
}

/// Стан у тій самій базі, щоб останнє місце жило поруч із нотатками (і в UI-тестах скидалося разом із ними).
/// Помилки читання дають `nil`, помилки запису ігноруються: це лише зручність.
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

/// Закладки, підсвітки й нотатки для SwiftUI: усе в пам'яті, кожна зміна одразу пишеться в базу.
@MainActor @Observable
public final class UserData {
    public private(set) var bookmarks: [Bookmark] = []
    public private(set) var highlights: [VerseKey: HighlightColor] = [:]
    public private(set) var notes: [VerseKey: Note] = [:]
    /// Остання помилка запису або читання бази; дані в пам'яті лишаються.
    public private(set) var lastError: String?

    @ObservationIgnored private let database: UserDatabase?
    @ObservationIgnored private let now: () -> Date

    public init(database: UserDatabase?, now: @escaping () -> Date = Date.init) {
        self.database = database
        self.now = now
        load()
    }

    /// Базу не вдалося відкрити: працюємо в пам'яті й показуємо причину.
    public convenience init(unavailable error: any Error) {
        self.init(database: nil)
        lastError = "\(error)"
    }

    // MARK: Закладки

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

    // MARK: Підсвітки

    public func highlight(for key: VerseKey) -> HighlightColor? { highlights[key] }

    /// `nil` прибирає підсвітку.
    public func setHighlight(_ color: HighlightColor?, for keys: some Collection<VerseKey>) {
        // Усі вірші однією транзакцією; пам'ять міняємо лише після успішного запису.
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

    // MARK: Нотатки

    public func note(for key: VerseKey) -> Note? { notes[key] }

    /// Порожній текст видаляє нотатку.
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

    /// Нотатки, що містять запит (без регістру й «ё»), у порядку книг.
    public func searchNotes(_ query: String) -> [Note] {
        let needle = SearchText.fold(query.trimmingCharacters(in: .whitespacesAndNewlines)).lowercased()
        guard !needle.isEmpty else { return [] }
        return notes.values
            .filter { SearchText.fold($0.text).lowercased().contains(needle) }
            .sorted { $0.key < $1.key }
    }

    public var sortedNotes: [Note] { notes.values.sorted { $0.key < $1.key } }

    // MARK: Позначки розділу

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

    // MARK: Експорт

    public func exportJSON() throws -> Data {
        let export = UserDataExport(
            bookmarks: bookmarks,
            highlights: highlights.sorted { $0.key < $1.key }.map { .init(key: $0.key, color: $0.value) },
            notes: sortedNotes)
        return try JSONEncoder.userData.encode(export)
    }

    /// Markdown із посиланнями мовою перекладу на екрані.
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

    // MARK: База

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

    /// Одна транзакція; `false` — запис не вдався, стан у пам'яті не міняємо. Без бази — лише пам'ять.
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

    /// Користувач закрив повідомлення про помилку.
    public func dismissError() { lastError = nil }

    /// Зміни живуть лише до виходу: базу не вдалося відкрити.
    public var isInMemoryOnly: Bool { database == nil }
}
