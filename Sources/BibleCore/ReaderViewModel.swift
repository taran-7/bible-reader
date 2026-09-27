import Foundation
import Observation

/// Стан читача для SwiftUI: переклад, місце, вірші, пошук, помилка бази.
@MainActor @Observable
public final class ReaderViewModel {
    public var translation: Translation = .kjv {
        didSet {
            guard translation != oldValue else { return }
            reload()
            savePosition()
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
    private var takenFocusRequest = 0
    public var query = ""
    /// `nil`, коли пошук не активний; порожній масив означає «Нічого не знайдено».
    /// Містить завантажені сторінки; решту довантажує `loadMore()` (FR-20).
    public private(set) var results: [SearchResult]?
    /// Загальна кількість збігів в області, для напису «Знайдено: N».
    public private(set) var resultTotal = 0
    /// Помилка довантаження наступної сторінки: вже завантажені результати лишаються на екрані.
    public private(set) var pageError: String?
    /// Область пошуку (FR-19); зміна перезапускає активний пошук.
    public var searchScope: SearchScope = .bible {
        didSet {
            guard searchScope != oldValue else { return }
            if results != nil || searchError != nil { runSearch(submittedQuery) }
        }
    }
    public static let pageSize = 100
    /// Запит, за яким отримано `results` (поле пошуку могли вже змінити).
    public private(set) var submittedQuery = ""
    public private(set) var loadError: String?
    /// NFR-3: мілісекунди від старту процесу до першого показаного розділу з віршами (записує `ChapterView`).
    public private(set) var launchMilliseconds: Int?

    /// Перший виклик із непорожнім розділом фіксує час запуску; наступні ігноруються.
    public func markFirstChapterShown(now: Date = Date()) {
        guard launchMilliseconds == nil, !verses.isEmpty else { return }
        launchMilliseconds = LaunchClock.millisecondsSinceStart(now: now)
    }
    /// Помилка пошуку (не плутати з «Нічого не знайдено»).
    public private(set) var searchError: String?

    private let repository: BibleRepository?
    @ObservationIgnored private let positionStore: KeyValueStore?

    /// Останнє місце читання (FR-25): переклад, книга, розділ.
    struct Position: Codable {
        let translation: Translation
        let book: Int
        let chapter: Int
    }

    public static let positionKey = "lastPosition"

    /// `positionStore` зберігає останнє місце; без нього додаток відкривається на Бутті 1.
    public init(positionStore: KeyValueStore? = nil, openRepository: () throws -> BibleRepository) {
        self.positionStore = positionStore
        do {
            repository = try openRepository()
        } catch {
            repository = nil
            loadError = "\(error)"
            return
        }
        if let data = positionStore?.data(forKey: Self.positionKey),
           let position = try? JSONDecoder().decode(Position.self, from: data),
           Book(number: position.book) != nil, position.chapter > 0 {
            // Присвоєння в init не викликає didSet; розділ поза книгою обріже `reload`.
            translation = position.translation
            location = Location(book: position.book, chapter: position.chapter)
        }
        reload()
        // `reload` міг обрізати розділ — зберігаємо вже дійсне місце.
        if positionStore != nil { savePosition() }
    }

    private func savePosition() {
        guard let positionStore else { return }
        let position = Position(translation: translation, book: location.book, chapter: location.chapter)
        guard let data = try? JSONEncoder().encode(position) else { return }
        positionStore.set(data, forKey: Self.positionKey)
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
        savePosition()
    }

    /// Відкриває вірш, до якого знайдено нотатку, і закриває результати.
    public func openNote(_ key: VerseKey) {
        results = nil
        open(Location(book: key.book, chapter: key.chapter), focus: key.verse)
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

    /// Область «поточна книга» для панелі над результатами; якщо вже шукаємо в книзі — саме вона.
    public var currentBookScope: SearchScope {
        if case .book = searchScope { return searchScope }
        return .book(location.book)
    }

    public var canLoadMore: Bool {
        guard let results else { return false }
        return results.count < resultTotal
    }

    /// Наступна сторінка результатів (прокручування до кінця списку).
    public func loadMore() {
        guard let repository, let loaded = results, canLoadMore else { return }
        do {
            let page = try repository.searchPage(submittedQuery, translation: translation, scope: searchScope,
                                                 offset: loaded.count, limit: Self.pageSize)
            results = loaded + page.results
            // Коротка сторінка — кінець списку, навіть якщо лічильник обіцяв більше: інакше індикатор висів би вічно.
            resultTotal = page.results.count < Self.pageSize ? loaded.count + page.results.count : page.total
            pageError = nil
        } catch {
            pageError = "\(error)"
        }
    }

    private func runSearch(_ text: String) {
        guard let repository else { return }
        submittedQuery = text
        do {
            let page = try repository.searchPage(text, translation: translation, scope: searchScope, offset: 0, limit: Self.pageSize)
            results = page.results
            resultTotal = page.total
            searchError = nil
            pageError = nil
        } catch {
            results = nil
            resultTotal = 0
            searchError = "\(error)"
        }
    }

    /// Вірш для фокусу, один раз на кожен запит: повторне відображення розділу
    /// (після очищення пошуку) не забирає фокус у поля пошуку.
    public func takeFocus() -> Int? {
        guard focusRequest != takenFocusRequest, let focusedVerse else { return nil }
        takenFocusRequest = focusRequest
        return focusedVerse
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
