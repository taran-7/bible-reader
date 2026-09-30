import Foundation
import GRDB
import Observation

/// A draft of a sermon or a few thoughts (FR-38): a title and Markdown text.
public struct Draft: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public var title: String
    public var text: String
    public let created: Date
    public var updated: Date

    public init(id: String, title: String, text: String, created: Date, updated: Date) {
        self.id = id
        self.title = title
        self.text = text
        self.created = created
        self.updated = updated
    }

    /// The title for the list and headers; an empty one shows as «Без назви» (Untitled).
    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Без назви" : trimmed
    }

    /// The start of the text as one line for the list.
    public var preview: String {
        let line = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " ")
        return line.count > 120 ? String(line.prefix(120)) + "…" : line
    }

    /// A Markdown file: `# title`, an empty line, the text (FR-40).
    public var markdown: String { "# \(displayTitle)\n\n\(text.trimmingCharacters(in: .whitespacesAndNewlines))\n" }

    /// The "New sermon" template (FR-39).
    public static let sermonTemplate = """
        ## Тема

        ## Основний текст

        ## Вступ

        ## 1.

        ## 2.

        ## 3.

        ## Ілюстрація

        ## Застосування

        ## Заклик

        """
}

/// A passage reference found in the draft text.
public struct DraftReference: Equatable, Sendable {
    public let range: Range<String.Index>
    public let reference: Reference
    static let maxRange = 200

    /// The reference's verses in KJV numbering: every verse of a range.
    public var keys: [VerseKey] {
        // `find` returns only references with a verse.
        let start = reference.verseStart!
        var end = start
        // The longest chapter has 176 verses: «Ин 3:1-9999999» must not create millions of keys on every keystroke.
        if let verseEnd = reference.verseEnd { end = min(verseEnd, start + Self.maxRange) }
        return (start...end).map { VerseKey(book: reference.book, chapter: reference.chapter, verse: $0) }
    }
}

/// Live references in the text (FR-38): up to three words of a book name, `chapter:verse`, an optional range.
/// Each candidate is checked by `Reference.parse`, from the longest name to the shortest: so «див. Ин 3:16» gives «Ин 3:16»,
/// and «1 Кор 13:4» is not «Кор 13:4». Without a verse (`Ин 3`) we do not recognize it: too many false matches in plain text.
public enum DraftReferences {
    private static var pattern: Regex<(Substring, Substring, Substring, Substring, Substring?)> { #/((?:[1-3]\s?)?\p{L}[\p{L}'’ʼ]*\.?(?:\s+(?:[1-3]\s?)?\p{L}[\p{L}'’ʼ]*\.?){0,2})\s*(\d+)\s*:\s*(\d+)(?:\s*[-–]\s*(\d+))?/# }

    public static func find(in text: String) -> [DraftReference] {
        var found: [DraftReference] = []
        for match in text.matches(of: pattern) {
            let numbers = text[match.output.1.endIndex..<match.range.upperBound]
            // Name words with their positions: try from the longest tail down to one word.
            let prefix = match.output.1
            let starts = prefix.indices.filter { index in
                index == prefix.startIndex || (!prefix[index].isWhitespace && prefix[prefix.index(before: index)].isWhitespace)
            }
            for start in starts {
                let candidate = String(text[start..<prefix.endIndex]) + " " + numbers
                if let reference = Reference.parse(candidate), reference.verseStart != nil {
                    found.append(DraftReference(range: start..<match.range.upperBound, reference: reference))
                    break
                }
            }
        }
        return found
    }
}

/// Drafts in the user database (FR-38…FR-40): every change is written immediately; the active draft and panel state are for SwiftUI.
@MainActor @Observable
public final class DraftStore {
    /// Newest first.
    public private(set) var drafts: [Draft] = []
    public private(set) var lastError: String?
    /// The draft in the editor; "To draft" appends to exactly this one.
    public var activeID: String?
    /// The "Drafts" panel to the right of the text.
    public var isOpen = false
    /// "Sermon" mode: the active draft across the whole window (FR-40).
    public var isPresenting = false
    /// The "Sermon" mode font size: ⌘+ / ⌘− in the View menu change it while the mode is open.
    public private(set) var sermonFontSize = 30.0

    /// The ⌘+ / ⌘− step in "Sermon" mode; limits 16…72 pt.
    public func changeSermonFont(by delta: Double) {
        sermonFontSize = min(max(sermonFontSize + delta, 16), 72)
    }
    /// The list shows only drafts mentioning this verse (a click on the marker next to the verse, FR-39); `nil` means all.
    public var mentionFilter: VerseKey?
    /// KJV verse → drafts referencing it. Observable: markers next to verses (FR-39)
    /// must appear as soon as a reference lands in a draft, not on the next redraw.
    private var mentions: [VerseKey: Set<String>] = [:]

    @ObservationIgnored private let database: UserDatabase?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let makeID: () -> String

    public init(database: UserDatabase?, now: @escaping () -> Date = Date.init,
                makeID: @escaping () -> String = { UUID().uuidString }) {
        self.database = database
        self.now = now
        self.makeID = makeID
        load()
    }

    public var active: Draft? { drafts.first { $0.id == activeID } }

    /// The panel list: search by title and text (ignoring case and «ё»), filter by verse.
    public func list(matching query: String) -> [Draft] {
        let needle = SearchText.fold(query.trimmingCharacters(in: .whitespacesAndNewlines)).lowercased()
        return drafts.filter { draft in
            if let mentionFilter, !mentions[mentionFilter, default: []].contains(draft.id) { return false }
            return needle.isEmpty || SearchText.fold(draft.title + "\n" + draft.text).lowercased().contains(needle)
        }
    }

    /// A new draft becomes active and first in the list.
    @discardableResult
    public func create(title: String = "", text: String = "") -> Draft {
        let date = now()
        let draft = Draft(id: makeID(), title: title, text: text, created: date, updated: date)
        guard write("INSERT INTO draft (id, title, text, created, updated) VALUES (?, ?, ?, ?, ?)",
                    [draft.id, title, text, date.timeIntervalSince1970, date.timeIntervalSince1970]) else { return draft }
        drafts.insert(draft, at: 0)
        activeID = draft.id
        index(draft)
        return draft
    }

    /// "New sermon" (FR-39).
    @discardableResult
    public func createSermon() -> Draft { create(text: Draft.sermonTemplate) }

    /// A title or text change; the draft moves to the top of the list.
    public func update(_ id: String, title: String? = nil, text: String? = nil) {
        guard let position = drafts.firstIndex(where: { $0.id == id }) else { return }
        var draft = drafts[position]
        draft.title = title ?? draft.title
        draft.text = text ?? draft.text
        guard draft != drafts[position] else { return }
        draft.updated = now()
        guard write("UPDATE draft SET title = ?, text = ?, updated = ? WHERE id = ?",
                    [draft.title, draft.text, draft.updated.timeIntervalSince1970, id]) else { return }
        drafts.remove(at: position)
        drafts.insert(draft, at: 0)
        index(draft)
    }

    public func delete(_ id: String) {
        guard write("DELETE FROM draft WHERE id = ?", [id]) else { return }
        drafts.removeAll { $0.id == id }
        if activeID == id {
            activeID = nil
            isPresenting = false
        }
        unindex(id)
    }

    /// "To draft": a paragraph at the end of the active draft; without an active one, a new draft (FR-38, FR-39).
    public func append(_ snippet: String) {
        let snippet = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !snippet.isEmpty else { return }
        guard let draft = active else {
            create(text: snippet + "\n")
            return
        }
        let body = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        update(draft.id, text: (body.isEmpty ? "" : body + "\n\n") + snippet + "\n")
    }

    /// At least one draft references one of these KJV verses (a merged Synodal verse has several keys).
    public func isMentioned(_ keys: [VerseKey]) -> Bool {
        keys.contains { !(mentions[$0]?.isEmpty ?? true) }
    }

    /// A click on the marker next to a verse: the panel with the list of drafts mentioning it.
    public func showMentions(of keys: [VerseKey]) {
        mentionFilter = keys.first { !(mentions[$0]?.isEmpty ?? true) }
        activeID = nil
        isOpen = true
    }

    public func dismissError() { lastError = nil }

    // MARK: Index and database

    private func index(_ draft: Draft) {
        unindex(draft.id)
        for found in DraftReferences.find(in: draft.text) {
            for key in found.keys { mentions[key, default: []].insert(draft.id) }
        }
    }

    private func unindex(_ id: String) {
        for key in mentions.keys { mentions[key]?.remove(id) }
    }

    private func load() {
        guard let database else { return }
        do {
            drafts = try database.queue.read { db in
                try Row.fetchAll(db, sql: "SELECT * FROM draft ORDER BY updated DESC").map { row in
                    Draft(id: row["id"], title: row["title"], text: row["text"],
                          created: Date(timeIntervalSince1970: row["created"]), updated: Date(timeIntervalSince1970: row["updated"]))
                }
            }
            drafts.forEach(index)
        } catch {
            lastError = "\(error)"
        }
    }

    /// `false`: the write failed, the in-memory state is not changed. Without a database, memory only.
    private func write(_ sql: String, _ arguments: StatementArguments) -> Bool {
        guard let database else { return true }
        do {
            try database.queue.write { try $0.execute(sql: sql, arguments: arguments) }
            return true
        } catch {
            lastError = "\(error)"
            return false
        }
    }
}

/// A draft block for the preview, "Sermon" mode and printing (FR-38, FR-40). An `inline` string is Markdown
/// with emphasis and links only: SwiftUI `Text` does not draw headings and lists itself, so blocks are parsed here.
public enum DraftBlock: Equatable, Sendable {
    case heading(level: Int, inline: String)
    case bullet(inline: String)
    case paragraph(inline: String)
    case spacer
}

public enum DraftRendering {
    /// The URL scheme for passage links in the preview; handled by the app's `OpenURLAction`.
    public static let linkScheme = "biblereader"

    public static func blocks(_ text: String) -> [DraftBlock] {
        var blocks: [DraftBlock] = []
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                if blocks.last != .spacer, !blocks.isEmpty { blocks.append(.spacer) }
            } else if let hashes = line.firstIndex(where: { $0 != "#" }), line.hasPrefix("#"), line[hashes] == " " {
                let level = line.distance(from: line.startIndex, to: hashes)
                blocks.append(.heading(level: min(level, 3), inline: linked(String(line[hashes...].dropFirst()))))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                blocks.append(.bullet(inline: linked(String(line.dropFirst(2)))))
            } else {
                blocks.append(.paragraph(inline: linked(line)))
            }
        }
        if blocks.last == .spacer { blocks.removeLast() }
        return blocks
    }

    /// Passage references → Markdown links `[Ин 3:16](biblereader:43/3/16-16)`.
    static func linked(_ line: String) -> String {
        var result = ""
        var cursor = line.startIndex
        for found in DraftReferences.find(in: line) {
            let r = found.reference
            let keys = found.keys
            result += line[cursor..<found.range.lowerBound]
            result += "[\(line[found.range])](\(linkScheme):\(r.book)/\(r.chapter)/\(keys[0].verse)-\(keys[keys.count - 1].verse))"
            cursor = found.range.upperBound
        }
        return result + line[cursor...]
    }

    /// A link from the preview back to a passage; `nil` means a foreign link (opens in the browser).
    public static func reference(fromLink link: String) -> Reference? {
        let prefix = linkScheme + ":"
        guard link.hasPrefix(prefix) else { return nil }
        let parts = link.dropFirst(prefix.count).split(separator: "/")
        let verses = parts.count == 3 ? parts[2].split(separator: "-").compactMap { Int($0) } : []
        guard parts.count == 3, let book = Int(parts[0]), let chapter = Int(parts[1]), verses.count == 2,
              Book(number: book) != nil else { return nil }
        return Reference(book: book, chapter: chapter, verseStart: verses[0], verseEnd: verses[1])
    }
}
