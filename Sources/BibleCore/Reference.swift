import Foundation

/// Посилання на місце Писання: `Ин 3:16`, `John 3`, `1 Кор 13:4-7`.
public struct Reference: Hashable, Sendable {
    public let book: Int
    public let chapter: Int
    public let verseStart: Int?
    public let verseEnd: Int?

    public init(book: Int, chapter: Int, verseStart: Int? = nil, verseEnd: Int? = nil) {
        self.book = book
        self.chapter = chapter
        self.verseStart = verseStart
        self.verseEnd = verseStart == nil || verseEnd == verseStart ? nil : verseEnd
    }

    /// `nil`, якщо рядок не є посиланням.
    public static func parse(_ input: String) -> Reference? {
        let pattern = /^\s*(.*?\p{L}.*?)\s*(\d+)(?:\s*:\s*(\d+)(?:\s*[-–]\s*(\d+))?)?\s*$/
        guard let match = input.wholeMatch(of: pattern),
              let book = bookIndex[normalize(String(match.1))],
              let chapter = Int(match.2), chapter > 0
        else { return nil }

        let start = match.3.flatMap { Int($0) }
        let end = match.4.flatMap { Int($0) }
        if let start, start < 1 { return nil }
        if let start, let end, end < start { return nil }
        return Reference(book: book, chapter: chapter, verseStart: start, verseEnd: end)
    }

    /// `Ин. 3:16-18` для Синодального, `John 3:16-18` для KJV.
    public func format(in translation: Translation) -> String {
        "\(Reference.bookLabel(book, in: translation)) \(chapter)" + (verseStart.map { ":\($0)" + (verseEnd.map { "-\($0)" } ?? "") } ?? "")
    }

    static func bookLabel(_ number: Int, in translation: Translation) -> String {
        let abbreviation = Book(number: number)?.abbreviation(in: translation) ?? "\(number)"
        return translation == .synodal ? abbreviation + "." : abbreviation
    }

    /// Нижній регістр, без крапок і пробілів, ё → е.
    static func normalize(_ spelling: String) -> String {
        spelling.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .filter { !$0.isWhitespace && $0 != "." }
    }

    private static let bookIndex: [String: Int] = {
        var index: [String: Int] = [:]
        for book in Book.all {
            for spelling in book.spellings {
                index[normalize(spelling)] = book.number
            }
        }
        return index
    }()
}

/// Цитата для буфера обміну: `«текст» (Ин. 3:16)`.
public enum Quote {
    /// Вірші одного розділу; непослідовні номери записуються як `16-17,19`.
    public static func format(_ verses: [Verse]) -> String? {
        let sorted = verses.sorted { $0.verse < $1.verse }
        guard let first = sorted.first else { return nil }

        var runs: [(Int, Int)] = []
        for verse in sorted {
            if let last = runs.last, verse.verse == last.1 + 1 {
                runs[runs.count - 1].1 = verse.verse
            } else {
                runs.append((verse.verse, verse.verse))
            }
        }
        let verseList = runs.map { $0.0 == $0.1 ? "\($0.0)" : "\($0.0)-\($0.1)" }.joined(separator: ",")
        let label = Reference.bookLabel(first.book, in: first.translation)
        let text = sorted.map(\.text).joined(separator: " ")
        return "«\(text)» (\(label) \(first.chapter):\(verseList))"
    }
}
