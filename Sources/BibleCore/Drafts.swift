import Foundation
import GRDB
import Observation

/// Чорнетка проповіді чи кількох думок (FR-38): назва і текст Markdown.
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

    /// Назва для списку й заголовків; порожня — «Без назви».
    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Без назви" : trimmed
    }

    /// Початок тексту одним рядком для списку.
    public var preview: String {
        let line = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " ")
        return line.count > 120 ? String(line.prefix(120)) + "…" : line
    }

    /// Markdown-файл: `# назва`, порожній рядок, текст (FR-40).
    public var markdown: String { "# \(displayTitle)\n\n\(text.trimmingCharacters(in: .whitespacesAndNewlines))\n" }

    /// Шаблон «Нова проповідь» (FR-39).
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

/// Посилання на місце, знайдене в тексті чорнетки.
public struct DraftReference: Equatable, Sendable {
    public let range: Range<String.Index>
    public let reference: Reference
    static let maxRange = 200

    /// Вірші посилання в нумерації KJV: діапазон — кожен вірш.
    public var keys: [VerseKey] {
        // `find` повертає лише посилання з віршем.
        let start = reference.verseStart!
        var end = start
        // Найдовший розділ — 176 віршів: «Ин 3:1-9999999» не має створювати мільйони ключів на кожен символ.
        if let verseEnd = reference.verseEnd { end = min(verseEnd, start + Self.maxRange) }
        return (start...end).map { VerseKey(book: reference.book, chapter: reference.chapter, verse: $0) }
    }
}

/// Живі посилання в тексті (FR-38): до трьох слів назви книги, `розділ:вірш`, необов'язковий діапазон.
/// Кожен кандидат перевіряє `Reference.parse`, від найдовшої назви до найкоротшої: так «див. Ин 3:16» дає «Ин 3:16»,
/// а «1 Кор 13:4» — не «Кор 13:4». Без вірша (`Ин 3`) не розпізнаємо: забагато хибних збігів у звичайному тексті.
public enum DraftReferences {
    private static var pattern: Regex<(Substring, Substring, Substring, Substring, Substring?)> { #/((?:[1-3]\s?)?\p{L}[\p{L}'’ʼ]*\.?(?:\s+(?:[1-3]\s?)?\p{L}[\p{L}'’ʼ]*\.?){0,2})\s*(\d+)\s*:\s*(\d+)(?:\s*[-–]\s*(\d+))?/# }

    public static func find(in text: String) -> [DraftReference] {
        var found: [DraftReference] = []
        for match in text.matches(of: pattern) {
            let numbers = text[match.output.1.endIndex..<match.range.upperBound]
            // Слова назви з їхніми позиціями: пробуємо від найдовшого хвоста до одного слова.
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

/// Чорнетки в базі користувача (FR-38…FR-40): кожна зміна одразу пишеться; активна чорнетка і стан панелі — для SwiftUI.
@MainActor @Observable
public final class DraftStore {
    /// Найновіші першими.
    public private(set) var drafts: [Draft] = []
    public private(set) var lastError: String?
    /// Чорнетка в редакторі; «В чорнетку» дописує саме в неї.
    public var activeID: String?
    /// Панель «Чорнетки» праворуч від тексту.
    public var isOpen = false
    /// Режим «Проповідь»: активна чорнетка на все вікно (FR-40).
    public var isPresenting = false
    /// Розмір шрифту режиму «Проповідь»: ⌘+ / ⌘− меню «Вигляд» змінюють його, поки режим відкритий.
    public private(set) var sermonFontSize = 30.0

    /// Крок ⌘+ / ⌘− у режимі «Проповідь»; межі 16…72 pt.
    public func changeSermonFont(by delta: Double) {
        sermonFontSize = min(max(sermonFontSize + delta, 16), 72)
    }
    /// Список лише чорнеток, що згадують цей вірш (клік по позначці біля вірша, FR-39); `nil` — усі.
    public var mentionFilter: VerseKey?
    /// Вірш KJV → чорнетки, що на нього посилаються. Спостережуваний: позначки біля віршів (FR-39)
    /// мають з'явитися, щойно посилання потрапило в чорнетку, а не при наступному перемальовуванні.
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

    /// Список для панелі: пошук за назвою і текстом (без регістру й «ё»), фільтр за віршем.
    public func list(matching query: String) -> [Draft] {
        let needle = SearchText.fold(query.trimmingCharacters(in: .whitespacesAndNewlines)).lowercased()
        return drafts.filter { draft in
            if let mentionFilter, !mentions[mentionFilter, default: []].contains(draft.id) { return false }
            return needle.isEmpty || SearchText.fold(draft.title + "\n" + draft.text).lowercased().contains(needle)
        }
    }

    /// Нова чорнетка стає активною і першою в списку.
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

    /// «Нова проповідь» (FR-39).
    @discardableResult
    public func createSermon() -> Draft { create(text: Draft.sermonTemplate) }

    /// Зміна назви чи тексту; чорнетка піднімається нагору списку.
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

    /// «В чорнетку»: абзацом у кінець активної чорнетки; без активної — нова (FR-38, FR-39).
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

    /// Хоч одна чорнетка посилається на один із цих віршів KJV (злитий вірш Синодального — кілька ключів).
    public func isMentioned(_ keys: [VerseKey]) -> Bool {
        keys.contains { !(mentions[$0]?.isEmpty ?? true) }
    }

    /// Клік по позначці біля вірша: панель зі списком чорнеток, що його згадують.
    public func showMentions(of keys: [VerseKey]) {
        mentionFilter = keys.first { !(mentions[$0]?.isEmpty ?? true) }
        activeID = nil
        isOpen = true
    }

    public func dismissError() { lastError = nil }

    // MARK: Індекс і база

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

    /// `false` — запис не вдався, стан у пам'яті не міняємо. Без бази — лише пам'ять.
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

/// Блок чорнетки для перегляду, режиму «Проповідь» і друку (FR-38, FR-40). Рядок `inline` — Markdown
/// лише з виділенням і посиланнями: заголовки й списки SwiftUI `Text` сам не малює, тож блоки розбираємо тут.
public enum DraftBlock: Equatable, Sendable {
    case heading(level: Int, inline: String)
    case bullet(inline: String)
    case paragraph(inline: String)
    case spacer
}

public enum DraftRendering {
    /// Схема посилань на місця в перегляді; обробляє `OpenURLAction` додатка.
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

    /// Посилання на місця → Markdown-посилання `[Ин 3:16](biblereader:43/3/16-16)`.
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

    /// Посилання з перегляду назад у місце; `nil` — чуже посилання (відкриється браузером).
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
