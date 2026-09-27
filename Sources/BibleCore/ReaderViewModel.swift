import Foundation
import Observation

/// Стан читача для SwiftUI: переклад, місце, вірші, пошук, помилка бази.
@MainActor @Observable
public final class ReaderViewModel {
    public var translation: Translation = .kjv {
        didSet {
            guard translation != oldValue else { return }
            reload()
            // Той самий запит, що дав результати, а не недописаний текст у полі.
            if results != nil || searchError != nil { runSearch(submittedQuery) }
        }
    }
    public private(set) var location = Location(book: 1, chapter: 1)
    public private(set) var books: [Book] = []
    public private(set) var chapterCount = 0
    public private(set) var verses: [Verse] = []
    /// Вірш, до якого треба прокрутити і який підсвітити.
    public var focusedVerse: Int?
    /// Змінюється на кожен запит фокусу, навіть якщо номер вірша той самий
    /// (Ин 3:16 → Рим 3:16), щоб SwiftUI `onChange` спрацював.
    public private(set) var focusRequest = 0
    public var query = ""
    /// `nil`, коли пошук не активний; порожній масив означає «Нічого не знайдено».
    public private(set) var results: [SearchResult]?
    /// Запит, за яким отримано `results` (поле пошуку могли вже змінити).
    public private(set) var submittedQuery = ""
    public private(set) var loadError: String?
    /// Помилка пошуку (не плутати з «Нічого не знайдено»).
    public private(set) var searchError: String?

    private let repository: BibleRepository?

    public init(openRepository: () throws -> BibleRepository) {
        do {
            repository = try openRepository()
        } catch {
            repository = nil
            loadError = "\(error)"
            return
        }
        reload()
    }

    public var canGoPrevious: Bool { navigator.previous(from: location) != nil }
    public var canGoNext: Bool { navigator.next(from: location) != nil }

    public func goPrevious() {
        if let target = navigator.previous(from: location) { open(target) }
    }

    public func goNext() {
        if let target = navigator.next(from: location) { open(target) }
    }

    public func open(_ target: Location, focus verse: Int? = nil) {
        location = target
        focusedVerse = verse
        if verse != nil { focusRequest += 1 }
        reload()
    }

    /// Відкриває вірш і закриває список результатів.
    public func open(_ result: SearchResult) {
        results = nil
        open(Location(book: result.verse.book, chapter: result.verse.chapter), focus: result.verse.verse)
    }

    /// Посилання веде до місця, інакше повнотекстовий пошук в активному перекладі.
    public func submitSearch() {
        guard let repository else { return }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            results = nil
            searchError = nil
        } else if let reference = Reference.parse(text) {
            results = nil
            searchError = nil
            open(Location(book: reference.book, chapter: reference.chapter), focus: reference.verseStart)
        } else {
            runSearch(text)
        }
    }

    private func runSearch(_ text: String) {
        guard let repository else { return }
        submittedQuery = text
        do {
            results = try repository.search(text, translation: translation, limit: 200)
            searchError = nil
        } catch {
            results = nil
            searchError = "\(error)"
        }
    }

    public func quote(for selectedVerses: Set<Int>) -> String? {
        Quote.format(verses.filter { selectedVerses.contains($0.verse) })
    }

    private var navigator: Navigator {
        Navigator { [repository, translation] book in
            (try? repository?.chapterCount(book: book, translation: translation)) ?? 0
        }
    }

    private func reload() {
        guard let repository else { return }
        do {
            books = try repository.books(translation: translation)
            chapterCount = try repository.chapterCount(book: location.book, translation: translation)
            if chapterCount > 0, location.chapter > chapterCount {
                location = Location(book: location.book, chapter: chapterCount)
            }
            verses = try repository.verses(book: location.book, chapter: location.chapter, translation: translation)
        } catch {
            loadError = "\(error)"
        }
    }
}
