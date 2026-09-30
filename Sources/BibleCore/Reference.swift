import Foundation

/// A scripture reference: `Ин 3:16`, `John 3`, `1 Кор 13:4-7`.
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

    /// `nil` if the string is not a reference.
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

    /// `Ин. 3:16-18` for the Synodal, `John 3:16-18` for KJV, `Ів. 3:16` for Ohienko, `J 3:16` for BKR.
    public func format(in translation: Translation) -> String {
        "\(Reference.bookLabel(book, in: translation)) \(chapter)" + (verseStart.map { ":\($0)" + (verseEnd.map { "-\($0)" } ?? "") } ?? "")
    }

    static func bookLabel(_ number: Int, in translation: Translation) -> String {
        let abbreviation = Book(number: number)?.abbreviation(in: translation) ?? "\(number)"
        // Cyrillic abbreviations with a period (`Ин. 3:16`, `Ів. 3:16`), Latin ones without.
        switch translation.language {
        case .russian, .ukrainian: return abbreviation + "."
        case .english, .czech, .other: return abbreviation
        }
    }

    /// Lowercase, no periods or spaces, ё → е, typographic apostrophes → '.
    static func normalize(_ spelling: String) -> String {
        spelling.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "ʼ", with: "'")
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

/// A clipboard quote with the full book name: `«текст» (От Иоанна 3:16)`;
/// several verses: `«16 текст⏎17 текст»⏎(От Иоанна 3:16-17)`.
public enum Quote {
    /// Verses of one chapter; non-consecutive numbers are written as `16-17,19`.
    public static func format(_ verses: [Verse]) -> String? {
        let sorted = verses.sorted { $0.verse < $1.verse }
        guard let first = sorted.first else { return nil }

        let verseList = Self.verseList(sorted.map(\.verse))
        let label = Book(number: first.book)?.name(in: first.translation) ?? "\(first.book)"
        let reference = "(\(label) \(first.chapter):\(verseList))"
        guard sorted.count > 1 else { return "«\(first.text)» \(reference)" }
        // Several verses: a number before each, each on a new line, the reference on a separate line.
        let lines = sorted.map { "\($0.verse) \($0.text)" }.joined(separator: "\n")
        return "«\(lines)»\n\(reference)"
    }

    /// Verse numbers of one chapter: `[16, 17, 19]` → `16-17,19`.
    static func verseList(_ numbers: [Int]) -> String {
        var runs: [(Int, Int)] = []
        for number in numbers.sorted() {
            if let last = runs.last, number == last.1 + 1 {
                runs[runs.count - 1].1 = number
            } else {
                runs.append((number, number))
            }
        }
        return runs.map { $0.0 == $0.1 ? "\($0.0)" : "\($0.0)-\($0.1)" }.joined(separator: ",")
    }
}
