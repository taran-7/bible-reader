import Foundation
import Observation

/// Стан читача для SwiftUI: переклад, місце, вірші, пошук, помилка бази.
@MainActor @Observable
public final class ReaderViewModel {
    public var translation: Translation = .kjv {
        didSet {
            guard translation != oldValue else { return }
            chapterPicker = nil
            if !keepLocationOnSwitch { remap(from: oldValue) }
            reload()
            savePosition()
            // Той самий запит, що дав результати, а не недописаний текст у полі.
            if results != nil || searchError != nil { runSearch(submittedQuery) }
        }
    }
    public private(set) var location = Location(book: 1, chapter: 1)
    public private(set) var books: [Book] = []
    public private(set) var chapterCount = 0
    public private(set) var verses: [Verse] = [] {
        didSet { rebuildParallel() }
    }
    /// Перший виділений вірш (з `ChapterView`): при перемиканні перекладу відкривається саме він (FR-27).
    public var anchorVerse: Int?
    /// Другий переклад поруч (FR-26); `nil` — паралельний перегляд вимкнено.
    public var parallelTranslation: Translation? {
        didSet { if parallelTranslation != oldValue { rebuildParallel() } }
    }
    /// Рядки паралельного перегляду: вірш основного перекладу і відповідні вірші другого.
    public private(set) var parallelRows: [ParallelRow] = []
    /// Таблиця відповідностей KJV ↔ Синодальний; будується при першій потребі з реальної бази.
    @ObservationIgnored private lazy var versification: Versification? =
        (repository as? SQLiteBibleRepository).flatMap { try? Versification.load(from: $0) }
    @ObservationIgnored private var keepLocationOnSwitch = false
    /// Вікно з номерами розділів книги, по якій клікнули в списку (FR-37); `nil` — закрито.
    public private(set) var chapterPicker: ChapterPicker?
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
    public struct Unavailable: Error, CustomStringConvertible {
        public var description: String { "база Біблії недоступна" }
    }

    /// Панелі вікна «Порівняти» (FR-36) з тієї самої бази.
    public func compare(_ request: CompareRequest, panels: ComparePanels) throws -> [ComparePanel] {
        guard let repository else { throw Unavailable() }
        return try VerseComparison.load(from: repository, book: request.book, chapter: request.chapter,
                                        verses: Set(request.verses), panels: panels)
    }

    /// Відкриває місце в іншому перекладі одним перезавантаженням.
    public func open(_ target: Location, in translation: Translation, focus verse: Int?) {
        if translation != self.translation {
            location = target
            // Місце вже в нумерації цього перекладу — не перераховуємо.
            keepLocationOnSwitch = true
            defer { keepLocationOnSwitch = false }
            self.translation = translation  // didSet: reload, savePosition, повтор пошуку
            focusedVerse = verse
            if verse != nil { focusRequest += 1 }
        } else {
            open(target, focus: verse)
        }
    }
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
        chapterPicker = nil
        location = target
        focusedVerse = verse
        if verse != nil { focusRequest += 1 }
        reload()
        savePosition()
    }

    /// Клік по книзі: показує її розділи поверх тексту, поточний розділ лишається відкритим (FR-37).
    public func pickBook(_ book: Int, from origin: ChapterPicker.Origin = .sidebar) {
        guard let count = try? repository?.chapterCount(book: book, translation: translation), count > 0 else {
            chapterPicker = nil
            return
        }
        chapterPicker = ChapterPicker(book: book, chapterCount: count,
                                      current: book == location.book ? location.chapter : nil, origin: origin)
    }

    /// Клік по назві розділу в тулбарі: розділи відкритої книги донизу від назви.
    public func pickCurrentBook() {
        pickBook(location.book, from: .title)
    }

    /// Клік по номеру розділу у вікні: відкриває розділ і закриває вікно та результати пошуку.
    public func pickChapter(_ chapter: Int) {
        guard let picker = chapterPicker else { return }
        chapterPicker = nil
        results = nil
        searchError = nil
        open(Location(book: picker.book, chapter: chapter))
    }

    public func dismissChapterPicker() {
        chapterPicker = nil
    }

    /// Відкриває вірш, до якого знайдено нотатку, і закриває результати.
    public func openNote(_ key: VerseKey) {
        results = nil
        openCanonical(book: key.book, chapter: key.chapter, verse: key.verse)
    }

    // MARK: Нумерація KJV для даних користувача (tech debt #24)

    /// Ключ вірша поточного розділу в нумерації KJV: так зберігаються нотатки, підсвітки й закладки,
    /// тож у Синодальному вони стоять на тому самому змісті. Вірш без відповідника — власний номер.
    public func canonicalKey(_ verse: Int) -> VerseKey {
        let key = VerseKey(book: location.book, chapter: location.chapter, verse: verse)
        return mapped(key, from: translation, to: .kjv) ?? key
    }

    /// Усі ключі KJV вірша поточного розділу: злитий вірш Синодального показує позначки всіх своїх частин.
    public func canonicalKeys(_ verse: Int) -> [VerseKey] {
        let key = VerseKey(book: location.book, chapter: location.chapter, verse: verse)
        guard !translation.sharesKJVNumbering, let all = versification?.allKJV(fromSynodal: key), !all.isEmpty
        else { return [canonicalKey(verse)] }
        return all
    }

    /// Закладка на поточний розділ у нумерації KJV: розділ KJV, куди потрапляє більшість віршів
    /// (Чис 13 Синодального починається з KJV 12:16, але це Чис 13).
    public var canonicalChapter: Bookmark.Target {
        let chapters = verses.map { canonicalKey($0.verse) }
        let counts = Dictionary(chapters.map { ($0.chapter, 1) }, uniquingKeysWith: +)
        let chapter = counts.max { ($0.value, -$0.key) < ($1.value, -$1.key) }?.key ?? location.chapter
        return Bookmark.Target(book: location.book, chapter: chapter, verse: nil)
    }

    /// Місце, збережене в нумерації KJV, у нумерації поточного перекладу.
    public func localReference(book: Int, chapter: Int, verse: Int?) -> Reference {
        let key = VerseKey(book: book, chapter: chapter, verse: verse ?? 1)
        let target = mapped(key, from: .kjv, to: translation) ?? key
        return Reference(book: target.book, chapter: target.chapter, verseStart: verse == nil ? nil : target.verse)
    }

    /// Відкриває місце, збережене в нумерації KJV.
    public func openCanonical(book: Int, chapter: Int, verse: Int?) {
        let reference = localReference(book: book, chapter: chapter, verse: verse)
        open(Location(book: reference.book, chapter: reference.chapter), focus: reference.verseStart)
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

    /// Вірш під тим самим змістом в іншій нумерації; без виділення — розділ за першим віршем.
    private func remap(from old: Translation) {
        let verse = anchorVerse ?? 1
        // Вірш без відповідника (доповнення Септуагінти) — найближчий попередній, що його має.
        var found: VerseKey?
        for candidate in stride(from: verse, through: 1, by: -1) {
            found = mapped(VerseKey(book: location.book, chapter: location.chapter, verse: candidate), from: old, to: translation)
            if found != nil { break }
        }
        guard let target = found else { return }
        location = Location(book: target.book, chapter: target.chapter)
        if anchorVerse != nil {
            focusedVerse = target.verse
            focusRequest += 1
        }
        anchorVerse = nil
    }

    private func mapped(_ key: VerseKey, from source: Translation, to target: Translation) -> VerseKey? {
        if source.sharesKJVNumbering == target.sharesKJVNumbering { return key }
        return versification?.map(key, from: source, to: target)
    }

    /// Вірші другого перекладу розкладаються по рядках основного: кожен стає біля вірша, у який
    /// відображається назад; вірш без відповідника (доповнення Септуагінти) — біля попереднього.
    private func rebuildParallel() {
        guard let other = parallelTranslation, other != translation, let repository, !verses.isEmpty else {
            parallelRows = []
            return
        }
        let book = location.book
        let chapter = location.chapter
        let targets = verses.compactMap { mapped(VerseKey(book: book, chapter: chapter, verse: $0.verse), from: translation, to: other) }
        let chapters = Set(targets.map(\.chapter)).sorted()
        var secondary: [[Verse]] = Array(repeating: [], count: verses.count)
        let rowOf = Dictionary(uniqueKeysWithValues: verses.enumerated().map { ($1.verse, $0) })
        var lastRow: Int?
        for secondChapter in chapters {
            let others = (try? repository.verses(book: book, chapter: secondChapter, translation: other)) ?? []
            for verse in others {
                let back = mapped(VerseKey(book: book, chapter: secondChapter, verse: verse.verse), from: other, to: translation)
                if let back {
                    guard back.chapter == chapter, let row = rowOf[back.verse] else { continue }
                    secondary[row].append(verse)
                    lastRow = row
                } else if let lastRow {
                    secondary[lastRow].append(verse)
                }
            }
        }
        parallelRows = zip(verses, secondary).map { ParallelRow(primary: $0, secondary: $1) }
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

/// Рядок паралельного перегляду (FR-26).
public struct ParallelRow: Identifiable, Sendable {
    public let primary: Verse
    public let secondary: [Verse]
    public var id: Int { primary.verse }
}

/// Вміст вікна вибору розділу: книга, кількість розділів і поточний розділ, якщо це відкрита книга.
public struct ChapterPicker: Equatable, Sendable {
    public let book: Int
    public let chapterCount: Int
    public let current: Int?
    /// Звідки відкрито: від книги в бічній панелі чи від назви розділу в тулбарі.
    public let origin: Origin
    public enum Origin: Sendable { case sidebar, title }
    /// Стовпців у сітці: стрілки ↑ ↓ переходять на рядок, тобто на стільки розділів.
    public static let columns = 10

    public init(book: Int, chapterCount: Int, current: Int?, origin: Origin = .sidebar) {
        self.book = book
        self.chapterCount = chapterCount
        self.current = current
        self.origin = origin
    }

    /// Розділ під курсором клавіатури, коли вікно відкрилося: поточний або перший.
    public var initialCursor: Int { current ?? 1 }

    /// Курсор після стрілки; не виходить за межі книги.
    public func move(_ cursor: Int, by delta: Int) -> Int {
        min(max(cursor + delta, 1), chapterCount)
    }
}
