import Foundation
import Observation

/// Стан читача для SwiftUI: переклад, місце, вірші, пошук, помилка бази.
@MainActor @Observable
public final class ReaderViewModel {
    public var translation: Translation = .kjv {
        didSet { if translation != oldValue { reload() } }
    }
    public private(set) var location = Location(book: 1, chapter: 1)
    public private(set) var books: [Book] = []
    public private(set) var chapterCount = 0
    public private(set) var verses: [Verse] = []
    /// Вірш, до якого треба прокрутити і який підсвітити.
    public var focusedVerse: Int?
    public var query = ""
    /// `nil`, коли пошук не активний; порожній масив означає «Нічого не знайдено».
    public private(set) var results: [SearchResult]?
    public private(set) var loadError: String?

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
        reload()
    }

    public func open(_ result: SearchResult) {
        open(Location(book: result.verse.book, chapter: result.verse.chapter), focus: result.verse.verse)
    }

    /// Посилання веде до місця, інакше повнотекстовий пошук в активному перекладі.
    public func submitSearch() {
        guard let repository else { return }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            results = nil
        } else if let reference = Reference.parse(text) {
            results = nil
            open(Location(book: reference.book, chapter: reference.chapter), focus: reference.verseStart)
        } else {
            results = (try? repository.search(text, translation: translation, limit: 200)) ?? []
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
